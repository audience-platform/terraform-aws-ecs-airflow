resource "aws_security_group" "datasync-task" {
  name        = "${var.resource_prefix}-datasync-${var.resource_suffix}"
  description = "${var.resource_prefix}-datasync-security-group-${var.resource_suffix}"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "EFS/NFS"
  }

  tags = {
    Name = "${var.resource_prefix}-datasync-task-${var.resource_suffix}"
  }
}

resource "aws_iam_role" "datasync-s3-access-role" {
  name               = "datasync-s3-access-role"
  assume_role_policy = "${data.aws_iam_policy_document.datasync_assume_role.json}"
}

resource "aws_iam_role_policy" "datasync-s3-access-policy" {
  name   = "${var.resource_prefix}-datasync-s3-access-policy-${var.resource_suffix}"
  role   = "${aws_iam_role.datasync-s3-access-role.name}"
  policy = "${data.aws_iam_policy_document.bucket_access.json}"
}


resource "aws_datasync_location_s3" "this" {
  s3_bucket_arn = aws_s3_bucket.airflow[0].arn
  subdirectory  = "${var.datasync_location_s3_subdirectory}"

  s3_config {
    bucket_access_role_arn = "${aws_iam_role.datasync-s3-access-role.arn}"
  }

  tags = {
    Name = "datasync-location-s3"
  }
}

resource "aws_datasync_location_efs" "this" {
  count = length(aws_efs_mount_target.this)
  efs_file_system_arn = aws_efs_mount_target.this[count.index].file_system_arn

  ec2_config {
    security_group_arns = [aws_security_group.efs.arn]
    subnet_arn          = aws_subnet.subnet.arn
  }
}

resource "aws_datasync_task" "dags_sync" {
  count = length(aws_datasync_location_efs.this)
  destination_location_arn = aws_datasync_location_s3.this.arn
  name                     = "${var.resource_prefix}-dags_sync-${var.resource_suffix}"
  source_location_arn      = aws_datasync_location_efs.this[count.index].arn
}