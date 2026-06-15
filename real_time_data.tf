locals {
  real_time_data_topic_name = local.real_time_data_bucket_region == "us-east-1" ? "realtime-event-topic-trigger" : "realtime-event-topic-trigger-${local.real_time_data_bucket_region}"
  real_time_data_topic_arn  = "arn:aws:sns:${local.real_time_data_bucket_region}:676206900418:${local.real_time_data_topic_name}"
}

resource "aws_s3_bucket_notification" "real_time_data" {
  count = local.real_time_data_enabled ? 1 : 0

  bucket = local.real_time_data_bucket_name

  topic {
    topic_arn = local.real_time_data_topic_arn
    events    = ["s3:ObjectCreated:*"]
  }

  lifecycle {
    precondition {
      condition     = local.real_time_data_bucket_name != ""
      error_message = "feature_config.real-time-data.bucket_name is required when real-time-data feature is enabled."
    }

    precondition {
      condition     = local.real_time_data_bucket_region != ""
      error_message = "feature_config.real-time-data.bucket_region is required when real-time-data feature is enabled."
    }
  }
}
