# general
variable "name" {
  type        = string
  description = <<-EOT
    The name of the project.
    Resources in AWS will be tagged with "Name: <name>".
    Any resources created will have this name as a tag.
    This tagging structure is assumed when looking up resources as well.
    We don't rely on "name" attributes(which only exist on a few resources),
    instead only the "Name" tag, which is available on all resources.
  EOT
}
variable "owner" {
  type        = string
  description = <<-EOT
    The email address of the person responsible for the infrastructure. 
    Resources in AWS will be tagged with "Owner: <owner>".
    This is helpful when multiple people are using the same AWS account.
    We recommend using an email address,
    or some identifier that can be used to contact the owner.
  EOT
}
# access variables
variable "vpc_name" {
  type        = string
  description = <<-EOT
    The name of the VPC to use.
    To generate a new VPC, set this and the vpc_cidr variable.
    If not creating a new VPC, this module will fail if the named VPC does not exist.
  EOT
}
variable "vpc_cidr" {
  type        = string
  description = <<-EOT
    Setting this tells the module to create a new VPC.
    The cidr to give the new VPC.    
  EOT
  default     = ""
}
variable "subnet_name" {
  type        = string
  description = <<-EOT
    The name of the subnet to use.
    To generate a new subnet, set this and the subnet_cidr variable.
    If not creating a new subnet, this module will fail if the subnet names does not exist.
  EOT
}
variable "subnet_cidr" {
  type        = string
  description = <<-EOT
    Setting this tells the module to create a new subnet.
    The cidr to give the new subnet, must be within the vpc_cidr.
  EOT
  default     = ""
}
variable "security_group_name" {
  type        = string
  description = <<-EOT
    The name of the security group to use.
    To generate a new security group, set this and the security_group_type variable.
    If not creating a new security group, this module will fail if the named security group does not exist.
  EOT
}
variable "security_group_type" {
  type        = string
  description = <<-EOT
    Setting this tells the module to create a new security group.
    The type of security group to create.
    The current valid options are: specific, ingress, egress, and public.
     - Specific generates rules that only allow access to and from the current public ip.
       - allows access to the new server from the computer running Terraform
     - Ingress adds to the rules generated by specific, allowing access to and from the vpc cidr.
       - allows access to the new server from other servers in the same VPC
     - Egress adds to the rules generated by ingress, allowing access to (but not from) the public internet.
        - allows the new server to access the public internet, this is helpful for installing updates and packages
     - Public adds to the rules generated by egress, allowing access to and from the public internet.
        - allows the new server to be accessed from the public internet, this is helpful for running a service
  EOT
  default     = ""
}
variable "security_group_ip" {
  type        = string
  description = <<-EOT
    The IP address to use when creating the specific type of security group.
    If this is not set, the module will attempt to discover the current public ip.    
  EOT
  default     = ""
}
variable "ssh_username" {
  type        = string
  description = <<-EOT
    The username to use when connecting to the server.
    This user will be generated on the server, and will have password-less sudo access.
    We recommend restricing this user as much as possible.
    The 32 character limit is due to using useradd to create the user.
  EOT
  validation {
    condition = (
      length(var.ssh_username) <= 32 ? true : false
    )
    error_message = "Username has a maximum of 32 characters."
  }
}
variable "ssh_key_name" {
  type        = string
  description = <<-EOT
    The name of the ssh key resource in AWS to use.
    To generate a new ssh key resource, set this and the ssh_key_content variable.
    Generating an ssh key resource isn't the same as generating a new ssh keypair.
    The user should generate their own ssh keypair, and provide the public key to this module.
  EOT
}
variable "ssh_key_content" {
  type        = string
  description = <<-EOT
    The content of the public ssh key to use.
    If this is set, a new ssh key resource will be generated in AWS.
    WARNING: This isn't your private key, it is the public key.
    Generating an ssh key resource isn't the same as generating a new ssh keypair.
    The user should generate their own ssh keypair, and provide the public key to this module.
  EOT
  default     = ""
}
# server
variable "server_type" {
  type        = string
  description = <<-EOT
    The type of server to create.
    This is one of the preconfigured types provided by our terraform-aws-server module.
    The current options are: medium, large, xl, and xxl.
     - Medium is 2 cpu, and 8gb of ram, and 200GB root storage (m5.large)
     - Large is 4 cpu, 8gb of ram, and 500GB root storage (c5.xlarge) *recommended
     - XL is 4 cpu, 16gb of ram, and 1TB root storage (t3.xlarge)
     - XXL is 8 cpu, 32gb of ram, and 2TB root storage (t3.2xlarge)
    WARNING: the larger the server, the more it will cost.
  EOT
  default     = "large"
}
variable "image_type" {
  type        = string
  description = <<-EOT
    The type of image to use.
    This is one of the preconfigured types provided by our terraform-aws-server module.
    The current options are: sles-15, sled-15-cis, rhel-8, and ubuntu-22
     - sles-15 is the latest SUSE Linux Enterprise Server 15 image supplied by Amazon
     - sles-15-cis is the latest SUSE Linux Enterprise Server 15 image supplied by the CIS
     - rhel-8 is the latest Red Hat Enterprise Linux 8 image supplied by Amazon
     - ubuntu-22 is the latest Ubuntu 22.04 image supplied by Cannonical in the AWS Marketplace
  EOT
  default     = "sles-15"
}
# download
variable "skip_download" {
  type        = bool
  description = <<-EOT
    A boolean value to skip downloading the RKE2 release and configuation files.
    This is useful when the files are already already downloaded at the local_file_path.
  EOT
  default     = false
}
variable "local_file_path" {
  type        = string
  description = <<-EOT
    A local file path where the RKE2 release and configuation files can be found or should be downloaded to.
    If this isn't set, the module will assume the files are already on the server at the remote_file_path.
    WARNING!:
      If this variable isn't set, Terraform can't track changes to the files.
      If the files are not on the server, the install script will fail.
  EOT
  default     = ""
}

# rke2
variable "rke2_version" {
  type        = string
  description = <<-EOT
    The RKE2 release to install.
    This must match the tag name of the release you would like to install.
    This is expected even when providing a local file path to install from.
  EOT
}
variable "remote_file_path" {
  type        = string
  description = <<-EOT
    The remote file path where the RKE2 release and configuation files can be found or should be placed.
    This defaults to "/home/<ssh_username>/rke2".
  EOT
  default     = ""
}
variable "join_token" {
  type        = string
  sensitive   = true
  description = <<-EOT
    The token to use when joining the server to a cluster.
    This is expected even when deploying a single server.
    This allows the user to deploy a single server,
    and then add more servers later without destroying the first server.
  EOT
}
variable "join_url" {
  type        = string
  description = <<-EOT
    The url of the registration endpoint on the first control plane server.
    This should be null on the first server, outputs from the first server include this value to use as input for others.
  EOT
  default     = null
}
variable "role" {
  type        = string
  description = <<-EOT
    The role of the server.
    The current options are: "server" and "agent".
     - A server is a control plane node.
     - An agent is a worker node.
    This is used by the RKE2 installer to start the correct services.
  EOT
  default     = "server"
}
