variable "config" {}

variable "python_versions" {
    type = list
    default = ["python3.8", "python3.9", "python3.10", "python3.11", "python3.12"]
}
