variable "create" {
    type = bool 
    default = true
}
variable "cluster_type" {
    description = "Cluster Type, permite apenas valores FARGATE e EC2. Que são compativeis com o base no tipo que precisa iniciar sua task."
    type = string 
}
variable "cluster_name" {
    description = "O nome do cluster que deseja iniciar" 
    type = string
}
variable "capacity_providers" {
    type = any
    default = []
}
variable "capacity_provider_strategy" {
    type = any
    default = []
}
variable "setting" {
    type = any
    default = []
}
variable "description" {
    type = string 
    default = null
}
variable "path" {
    type = string 
    default = "/"
}
variable "default_tags" {
    type = map
    default = {}
}
variable "task_definition" {
    type = any 
    default = []
}
variable "service" {
    type = any 
    default = []
}
variable "service_auto_scaling" {
    type = any 
    default = []
}
variable "service_load_balancing" {
    type = any 
    default = []
}
variable "log_driver" {
    type = any
    default = []
}
variable "cluster_resources" {
    type = any
    default = []
}
