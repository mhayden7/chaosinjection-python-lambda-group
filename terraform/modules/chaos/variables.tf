variable "config" {}

variable "python_versions_max_3_11" {
    type = list
    default = ["python3.8", "python3.9", "python3.10", "python3.11"]
}

variable "python_versions_max_3_12" {
  type = list
  default = ["python3.12"]
}