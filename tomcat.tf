provider "aws" {
  region = var.region
}

resource "aws_key_pair" "deployer" { 
  public_key = file("~/.ssh/id_rsa.pub")
} 

resource "aws_security_group" "tomcat" { 
  description = "Allow ssh and tomcat inbound traffic" 

  ingress { 
    from_port   = 22 
    to_port     = 22 
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"]   

} 
  ingress { 
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"]   

} 

  egress { 
    from_port       = 0 
    to_port         = 0 
    protocol        = "-1" 
    cidr_blocks     = ["0.0.0.0/0"] 
  } 
} 

data "aws_ami" "centos" {
  most_recent = true

  filter {
    name   = "name"
    values = ["CentOS Linux 7 x86_64 HVM EBS ENA*"]
  }
  
  owners = ["679593333241"]
}

resource "aws_instance" "bastion" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.centos
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.tomcat.id]
  
  
  tags = {
    Name = "Apache Tomcat"
  }

  provisioner "remote-exec" {
    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "centos"
      private_key = file("~/.ssh/id_rsa")
      }
      inline = [
        "sudo mkdir /opt; cd /opt",
        "sudo wget http://mirrors.fibergrid.in/apache/tomcat/tomcat-8/v8.5.35/bin/apache-tomcat-8.5.35.tar.gz",
        "sudo tar -xvzf /opt/apache-tomcat-8.5.35.tar.gz",
        "sudo chmod +x /opt/apache-tomcat-8.5.35/bin/startup.sh && sudo chmod +x /opt/apache-tomcat-8.5.35/bin/shutdown.sh",
        "sudo ln -s /opt/apache-tomcat-8.5.35/bin/startup.sh /usr/local/bin/tomcatup && sudo ln -s /opt/apache-tomcat-8.5.35/bin/shutdown.sh /usr/local/bin/tomcatdown",
        ]
      } 

  provisioner "file" {
    source      = "context.xml"
    destination = "/tomcat/webapps/manager/META-INF/context.xml"

    connection {
      host        = "${self.public_ip}"
      type        = "ssh"
      user        = "centos"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
  provisioner "file" {
    source      = "context.xml"
    destination = "/tomcat/webapps/host-manager/META-INF/context.xml"

    connection {
      host        = "${self.public_ip}"
      type        = "ssh"
      user        = "centos"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
  provisioner "file" {
    source      = "tomcat-users.cml"
    destination = "/tomcat/conf/tomcat-users.xml"

    connection {
      host        = "${self.public_ip}"
      type        = "ssh"
      user        = "${var.user}"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
}