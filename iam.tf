resource "aws_iam_role" "task_execution_role" {
  name = "task_execution_role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          Service : "ecs-tasks.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "task_execution_role_policy_attachment" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# EC2 Instance Role
resource "aws_iam_role" "ec2_node_role" {
  name = "EC2Role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          Service : "ec2.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachment" {
  role       = aws_iam_role.ec2_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role" # Important when using ec2 as type
}

# Lambda
resource "aws_iam_policy" "Lambda_Policy" {
  name = "Lambda_Role_Policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecs:ListServices",
          "ecs:UpdateService",
          "ecs:UpdateCapacityProvider",
          "ecs:DescribeClusters"
        ],
        "Resource" : [
          "arn:aws:ecs:us-east-1:${data.aws_caller_identity.current.account_id}:*/*"
        ]
      }
    ]
  })

  depends_on = [aws_iam_role.Lambda_Role]
}
resource "aws_iam_role_policy_attachment" "Lambda_Role_policy_Attachment" {
  role       = aws_iam_role.Lambda_Role.name
  policy_arn = aws_iam_policy.Lambda_Policy.arn
  depends_on = [aws_iam_role.Lambda_Role, aws_iam_policy.Lambda_Policy]
}