provider "aws" {
	region  = "ap-south-1"
	profile = "MohiniHMC"
	}

////Security Group
resource "aws_security_group" "task1_sg" {
	name        = "task1_sg"
	description = "Allow traffic"
	
	ingress {
	     description = "TCP"
	     from_port   = 22
	     to_port     = 22
	     protocol    = "tcp"
	     cidr_blocks = ["0.0.0.0/0"]
	}

	ingress {
	     description= "HTTP"
	     from_port  = 80
	     to_port    = 80
	     protocol   = "tcp"
	     cidr_blocks = ["0.0.0.0/0"]
	}
	
	egress {
	     from_port   = 0
	     to_port     = 0
      	     protocol    = "-1"
    	     cidr_blocks = ["0.0.0.0/0"]
  	} 

    tags = {
	     Name = "task1_sg"
	}
}

////EC2
resource "aws_instance" "web_server" {
	ami	        = "ami-0447a12f28fddb066"
	instance_type   = "t2.micro"
	key_name        = "terra-key2"
	security_groups = ["task1_sg"]

     connection {
	type        = "ssh"
	user        = "ec2-user"
	private_key = file("C:/Users/Hp/Desktop/terra-key2.pem")
	host        = aws_instance.web_server.public_ip
  }
	
     provisioner "remote-exec" {
	inline = [
	    "sudo yum install httpd php git   -y",
	    "sudo systemctl restart httpd",
	    "sudo systemctl enable httpd",
	]
}

     tags = {
	Name = "task1_web_server"
	}
}

output "os_out" {
	value = aws_instance.web_server.availability_zone
}


/////EBS
resource "aws_ebs_volume" "ebs1" {
	availability_zone = aws_instance.web_server.availability_zone
	size              = 1

      tags = {
	     Name ="task1_ebs"
	}

}

resource "aws_volume_attachment" "ebs_att" {
	device_name  = "/dev/sdh"
	volume_id    = aws_ebs_volume.ebs1.id
	instance_id  = aws_instance.web_server.id
	force_detach = true
}

output "ebs_out" {
      value = aws_ebs_volume.ebs1.id
}

output "osip_out"{
     value = aws_instance.web_server.public_ip
}


///PublicIPOutput
resource "null_resource" "nulllocal2" {
	provisioner "local-exec" {
		command = "echo ${aws_instance.web_server.public_ip} > publicip.txt"
	}
}



///Mounting EBS and git Clonning

resource "null_resource" "nullremote3" {
    depends_on = [
	aws_volume_attachment.ebs_att,
	]

connection {
	type        = "ssh"
	user        = "ec2-user"
	private_key = file("C:/Users/Hp/Desktop/terra-key2.pem")
	host        = aws_instance.web_server.public_ip
}

provisioner "remote-exec" {
	inline = [
	     "sudo mkfs.ext4  /dev/xvdh",
	     "sudo mount /dev/xvdh  /var/www/html",
	     "sudo rm  -rf  /var/www/html/*",
	     "sudo git clone https://github.com/mohini2317/Task1.git  /var/www/html/"
	]
       }
}

resource "null_resource" "nulllocal1" {
	depends_on = [
	        null_resource.nullremote3,
	]
}


/////S3

resource "aws_s3_bucket" "task1-s3-bucket23" {
	bucket  = "task1-s3-bucket23"
	acl     = "public-read"

      provisioner "local-exec" {
	command = "git clone https://github.com/mohini2317/Task11.git Task11"
    }
     provisioner "local-exec" {
	when    =   destroy
	command =   "echo Y | rmdir /s Task11"
    }

}

resource "aws_s3_bucket_object" "s3-image-upload" {
	bucket = aws_s3_bucket.task1-s3-bucket23.bucket
	key    = "exterra.png"
	source = "Task11/exterra.png"
	acl    = "public-read"
}


////cloudfront

variable "var1" {default = "S3-"}
    locals {
	s3_origin_id = "${var.var1}${aws_s3_bucket.task1-s3-bucket23.bucket}"
	image_url    = "${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.s3-image-upload.key}"
    }

resource "aws_cloudfront_distribution" "s3_distribution" {
      default_cache_behavior {
	allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
	cached_methods   = ["GET", "HEAD"]
	target_origin_id = local.s3_origin_id
      
      forwarded_values {
	query_string = false
	cookies {
                        forward = "none"
            }
     }
	min_ttl                = 0
	default_ttl            = 3600
	max_ttl                = 86400
	compres                = true
	viewer_protocol_policy = "allow-all"
    }
	enabled = true
	origin {
		domain_name = aws_s3_bucket.task1-s3-bucket23.bucket_domain_name
		origin_id   = local.s3_origin_id
    }
	restrictions {
        		geo_restriction {
		restriction_type = "whitelist"
		locations        = ["IN"]
        		}
    }

         viewer_certificate {
	cloudfront_default_certificate = true
    }

       connection {
	type        = "ssh"
	user        = "ec2-user"
	private_key = file("C:/Users/Hp/Desktop/terra-key2.pem")
	host        = aws_instance.web_server.public_ip	
}


        provisioner "remote-exec" {
	inline = [
	      "sudo su << EOF",
	      "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.s3-image-upload.key}'>\"  >> /var/www/html/index.html",
	      "EOF",
	]
}

       provisioner "local-exec" {
		command = "start chrome ${aws_instance.web_server.public_ip}"
	}
}      

