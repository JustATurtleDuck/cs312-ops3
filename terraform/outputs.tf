output "minecraft_public_ip" {
  description = "The public IP address of new Minecraft server"
  value       = aws_instance.minecraft_server.public_ip
}