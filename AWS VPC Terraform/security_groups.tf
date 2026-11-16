# SECURITY GROUPS (bina rules ke)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTPS from internet to ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-alb-sg"
    Project = var.project_name
  }
}

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Allow 8080 only from ALB security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-app-sg"
    Project = var.project_name
  }
}

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Allow 5432 only from App security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-db-sg"
    Project = var.project_name
  }
}

# ─────────────────────────────────────────────
# RULES (cycle break karne ke liye alag resources)
# ─────────────────────────────────────────────

# ALB: inbound 443 from internet
resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from anywhere"
}

# ALB: outbound 8080 to App SG
resource "aws_security_group_rule" "alb_egress_app" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.alb.id
  description              = "ALB to App servers on 8080"
}

# APP: inbound 8080 from ALB SG
resource "aws_security_group_rule" "app_ingress_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.app.id
  description              = "App port from ALB"
}

# APP: outbound 5432 to DB SG
resource "aws_security_group_rule" "app_egress_db" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.db.id
  security_group_id        = aws_security_group.app.id
  description              = "App to DB on 5432"
}

# DB: inbound 5432 from App SG
resource "aws_security_group_rule" "db_ingress_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.db.id
  description              = "PostgreSQL from App"
}