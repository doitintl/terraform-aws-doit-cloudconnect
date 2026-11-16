#!/usr/bin/env python3
"""Compare the IAM policies rendered by this module with the DoiT CloudFormation member template.

Run from the repository root after `terraform init -backend=false`.
"""

import argparse
import json
import re
import subprocess
import sys
import urllib.request

import yaml

DEFAULT_TEMPLATE_URL = "https://doit-cmp-ops-pub.s3.us-east-1.amazonaws.com/prod/member.yml"
ACCOUNT_ID = "123456789012"
BUCKET = "example-cloudtrail-bucket"
ALL_FEATURES = [
    "fsk8s_auto_connect",
    "ps4commitment_core",
    "ps4commitment_purchase",
    "spot-scaling",
    "real-time-data",
    "composer",
    "expert-advice",
    "reflex",
    "attribute",
]
SUBSTITUTIONS = {
    "AWS::Partition": "aws",
    "AWS::AccountId": ACCOUNT_ID,
    "RealTimeDataBucketName": BUCKET,
}

# Known, intentional differences: reported, never fail the check.
EXCEPTIONS = {
    "composer": "the module grants Composer read access with service-level wildcards",
    "reflex": "the module builds Reflex on AWS-managed job-function policies plus a delta policy",
    "role managed policies": "the module attaches job-function/Billing instead of AWSBillingReadOnlyAccess",
}


class TemplateLoader(yaml.SafeLoader):
    pass


def _substitute(text):
    return re.sub(r"\$\{([^}]+)\}", lambda m: SUBSTITUTIONS.get(m.group(1), m.group(0)), text)


def _construct_tag(loader, suffix, node):
    if isinstance(node, yaml.ScalarNode):
        value = loader.construct_scalar(node)
    elif isinstance(node, yaml.SequenceNode):
        value = loader.construct_sequence(node, deep=True)
    else:
        value = loader.construct_mapping(node, deep=True)
    if suffix == "Sub" and isinstance(value, str):
        return _substitute(value)
    if suffix == "If":
        return value[1]
    return {suffix: value}


TemplateLoader.add_multi_constructor("!", _construct_tag)


def load_template(source):
    if source.startswith("https://"):
        with urllib.request.urlopen(source, timeout=30) as response:
            text = response.read().decode()
    else:
        with open(source) as f:
            text = f.read()
    return yaml.load(text, Loader=TemplateLoader)["Resources"]


def render_module():
    expression = (
        "jsonencode({"
        "core = jsondecode(local.core_policy), "
        "write = jsondecode(local.write_policy), "
        "real_time_data = jsondecode(local.real_time_data_policy), "
        "composer = jsondecode(local.composer_policy), "
        "attribute = jsondecode(local.attribute_policy), "
        "reflex = jsondecode(local.reflex_policy), "
        "aws_managed = values(local.aws_managed_policy_arns), "
        "expert_advice_inline = jsondecode(local.expert_advice_inline_policy), "
        "expert_advice_managed = local.expert_advice_managed_policy_arns"
        "})"
    )
    variables = [
        "-var", "external_id=parity-check",
        "-var", f"account_id={ACCOUNT_ID}",
        "-var", f"additional_features={json.dumps(ALL_FEATURES)}",
        "-var", f'feature_config={{"real-time-data"={{bucket_name="{BUCKET}", bucket_region="us-east-1"}}}}',
    ]
    result = subprocess.run(
        ["terraform", "console", *variables],
        input=expression,
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(json.loads(result.stdout.strip()))


def _as_list(value):
    return value if isinstance(value, list) else [value]


def _statements(document):
    return [s for s in _as_list(document["Statement"]) if s is not None]


def actions_by_effect(document):
    actions = {}
    for statement in _statements(document):
        actions.setdefault(statement["Effect"], set()).update(_as_list(statement["Action"]))
    return actions


def normalized_statements(document):
    normalized = []
    for statement in _statements(document):
        entry = {k: v for k, v in statement.items() if k != "Sid"}
        for key in ("Action", "Resource", "NotResource"):
            if key in entry:
                entry[key] = sorted(_as_list(entry[key]))
        normalized.append(json.dumps(entry, sort_keys=True))
    return sorted(normalized)


def compare_actions(template_document, module_document):
    template, module = actions_by_effect(template_document), actions_by_effect(module_document)
    problems = []
    for effect in sorted(set(template) | set(module)):
        missing = sorted(template.get(effect, set()) - module.get(effect, set()))
        extra = sorted(module.get(effect, set()) - template.get(effect, set()))
        if missing:
            problems.append(f"{effect} actions only in the template: {', '.join(missing)}")
        if extra:
            problems.append(f"{effect} actions only in the module: {', '.join(extra)}")
    return problems


def compare_statements(template_document, module_document):
    template, module = normalized_statements(template_document), normalized_statements(module_document)
    problems = [f"statement only in the template: {s}" for s in template if s not in module]
    problems += [f"statement only in the module: {s}" for s in module if s not in template]
    return problems


def compare_arns(template_arns, module_arns):
    template, module = set(template_arns), set(module_arns)
    problems = [f"managed policy only in the template: {a}" for a in sorted(template - module)]
    problems += [f"managed policy only in the module: {a}" for a in sorted(module - template)]
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", default=DEFAULT_TEMPLATE_URL, help="member template URL or local path")
    args = parser.parse_args()

    resources = load_template(args.template)
    module = render_module()

    def policy(name):
        return resources[name]["Properties"]["PolicyDocument"]

    gateway = resources["DoiTSupportGatewayRole"]["Properties"]
    checks = {
        "core": compare_actions(policy("CoreManagedPolicy"), module["core"]),
        "write": compare_actions(policy("WritePermissionPolicy"), module["write"]),
        "real-time data": compare_statements(policy("RealTimeDataPolicy"), module["real_time_data"]),
        "composer": compare_actions(policy("ComposerPolicy"), module["composer"]),
        "attribute": compare_actions(policy("AttributePolicy"), module["attribute"]),
        "reflex": compare_actions(policy("ReflexPolicy"), module["reflex"]),
        "role managed policies": compare_arns(
            resources["CrossAccountRole"]["Properties"]["ManagedPolicyArns"], module["aws_managed"]
        ),
        "expert advice inline policy": compare_statements(gateway["Policies"][0]["PolicyDocument"], module["expert_advice_inline"]),
        "expert advice managed policies": compare_arns(gateway["ManagedPolicyArns"], module["expert_advice_managed"]),
    }

    failed = False
    for name, problems in checks.items():
        if not problems:
            print(f"ok       {name}")
        elif name in EXCEPTIONS:
            print(f"excepted {name}: {EXCEPTIONS[name]} ({len(problems)} differences)")
        else:
            failed = True
            print(f"FAILED   {name}")
            for problem in problems:
                print(f"           {problem}")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
