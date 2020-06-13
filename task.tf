provider "aws" {
  region = "ap-south-1"
  profile = "mysushant"
}
resource "tls_private_key" "key" {
   algorithm = "RSA"
}
output "key" {
  value = tls_private_key.key.public_key_openssh
}
output "key2" {
  value = tls_private_key.key.private_key_pem
}
resource "aws_key_pair" "key" {
  key_name = "mykey11"
  public_key = tls_private_key.key.public_key_openssh
}

resource "aws_security_group" "sec" {
  name        = "sec"
  vpc_id      = "vpc-13e5f87b"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "security_gp"
  }
}
resource "aws_instance" "instance" {
  ami             =  "ami-0447a12f28fddb066"
  instance_type   = "t2.micro"
  key_name        =  aws_key_pair.key.key_name
  security_groups =  [ aws_security_group.sec.name ]
  
  connection {
     type     = "ssh"
     user      = "ec2-user"
     private_key = tls_private_key.key.private_key_pem
     host     =  aws_instance.instance.public_ip
  }
   provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
    ]
  }		

 
  tags = {
    Name = "terraos1"
  }
}

resource "aws_ebs_volume" "aws_vol" {
    availability_zone    = aws_instance.instance.availability_zone
    size              = 1
    tags = {
        Name          = "webvol"
    }
}
resource "aws_s3_bucket" "sushant1508" {
    bucket                = "sushant1508"
    acl                   = "private"
    region                = "ap-south-1"
    tags = {
        Name              = "s3_bucket"
    }
}
locals {
    s3_origin_id          = "s3_origin"
}
resource "aws_s3_bucket_object" "object" {
    
    depends_on = [
        aws_s3_bucket.sushant1508,
    ]
    bucket                = "sushant1508"
    key                   = "sushant.JPG.JPG"
    source                = "C:/Users/KIIT/Pictures/Camera Roll/sushant.JPG.JPG"
}

resource "aws_s3_bucket_public_access_block" "public_storage" {
    depends_on = [
        aws_s3_bucket.sushant1508,
    ]
    bucket                = "sushant1508"
    block_public_acls     = false 
    block_public_policy   = false
}

resource "aws_cloudfront_distribution" "cld_dist" {
    origin{
        domain_name       = aws_s3_bucket.sushant1508.bucket_regional_domain_name
        origin_id         = local.s3_origin_id
    }
    
    enabled               = true
    is_ipv6_enabled       = true

    default_cache_behavior {
        allowed_methods   = ["DELETE","PATCH","OPTIONS","POST","PUT","GET", "HEAD"]
        cached_methods    = ["GET", "HEAD"]
        target_origin_id  = local.s3_origin_id

        forwarded_values {
            query_string  = false

            cookies {
                forward   = "none"
            }
        }

        min_ttl                = 0
        default_ttl            = 3600
        max_ttl                = 86400
        compress               = true
        viewer_protocol_policy = "allow-all"
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
}

resource "aws_volume_attachment" "vol_att" {
    device_name            = "/dev/sdf"
    volume_id              = aws_ebs_volume.aws_vol.id
    instance_id            = aws_instance.instance.id
    force_detach           = true
}
    
resource "null_resource" "nullremote1"{
    depends_on = [
        aws_volume_attachment.vol_att,
    ]
    
    connection{          
        type               = "ssh"
        user               = "ec2-user"
        private_key        = tls_private_key.key.private_key_pem
        host               = aws_instance.instance.public_ip
    }
    
    provisioner "remote-exec"{
        inline = [
            "sudo mkfs.ext4 /dev/xvdf",
            "sudo mount /dev/xvdf /var/www/html",
            "sudo rm -rf /var/www/html/*",
            "sudo git clone https://github.com/sushantb1508/task_cloud.git   /var/www/html"
        ]
    }
}
