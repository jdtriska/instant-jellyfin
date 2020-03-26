variable "AWS_ACCESS_KEY_ID" {
  type = string
}

variable "AWS_REGION" {
  type = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  type = string
}

variable "EBS_ROOT_VOLUME_SIZE" {
  type = string
  default = 8
}

variable "EBS_MEDIA_VOLUME_SIZE" {
  type = string
}

variable "EBS_MEDIA_VOLUME_TYPE" {
  type = string
  default = "st1"
}

variable "EC2_INSTANCE_TYPE" {
  type = string
}

variable "ENVIRONMENT" {
  type = string
}

variable "HOSTED_ZONE_ID" {
  type = string
}