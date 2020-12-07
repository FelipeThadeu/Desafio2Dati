#Creating EC2 Instance
#Server Linux
resource "aws_instance" "amazon-linux2" {
    ami = "ami-04bf6dcdc9ab498ca"
    instance_type = "t2.micro"
    key_name = "keypar-desafio1"
    associate_public_ip_address = "true"
    tags = {
        Name = "Amazon Linux 2"
    }
}

resource "aws_launch_configuration" "instance" {
    image_id=  "ami-04bf6dcdc9ab498ca"
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.sg_desafio2.id}"]
    key_name = "keypar-desafio1"
}

resource "aws_elb" "elb_desafio2" {
  availability_zones = ["us-east-1a", "us-east-1b"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  instances                   = [aws_instance.amazon-linux2.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "elb_desafio2"
  }
}

resource "aws_autoscaling_group" "scalegroup" {
    launch_configuration = "${aws_launch_configuration.instance.name}"
    availability_zones = ["us-east-1a", "us-east-1b"]
    min_size = 1
    max_size = 4
    enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]
    metrics_granularity = "1Minute"
    load_balancers = [aws_elb.elb_desafio2.id]
    health_check_type = "ELB"
    tag {
        key = "Name"
        value = "webserver000"
        propagate_at_launch = true
    }
}

resource "aws_autoscaling_policy" "autopolicy" {
    name = "terraform-autoplicy"
    scaling_adjustment = 1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = aws_autoscaling_group.scalegroup.name
}

resource "aws_cloudwatch_metric_alarm" "cpualarm" {
    alarm_name = "terraform-alarm"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "60"

    dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.scalegroup.name
    }

    alarm_actions = [aws_autoscaling_policy.autopolicy.arn]
}

resource "aws_autoscaling_policy" "autopolicy-down" {
    name = "terraform-autoplicy-down"
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = aws_autoscaling_group.scalegroup.name
}

resource "aws_cloudwatch_metric_alarm" "cpualarm-down" {
    alarm_name = "terraform-alarm-down"
    comparison_operator = "LessThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "10"

    dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.scalegroup.name
    }

    alarm_actions = [aws_autoscaling_policy.autopolicy-down.arn]
}

resource "aws_security_group" "sg_desafio2" {
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "allow_all"
    }
}