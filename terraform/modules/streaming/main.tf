resource "aws_kinesis_stream" "stream" {
  name             = "${var.project_name}-stream"
  shard_count      = var.shard_count
  retention_period = 24

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
    "WriteProvisionedThroughputExceeded"
  ]
  # Note: "WriteProvisionedThroughputExceeded" is CRITICAL for monitoring if we need to scale.

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Name = "${var.project_name}-stream"
  }
}