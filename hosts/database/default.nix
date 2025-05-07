{
  pkgs,
  config,
  ...
}: {
  # Enable PostgreSQL database server
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_14;

    # Enable network listening
    enableTCPIP = true;

    # PostgreSQL default settings
    settings = {
      max_connections = 100;
      shared_buffers = "128MB";
    };

    # Initial database setup with default user
    # Using authentication config properly - this was causing the stack overflow
    authentication = ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 trust
    '';

    # Initialize a sample database with secure password from agenix
    initialScript = pkgs.writeText "postgresql-init.sql" ''
      CREATE ROLE nixos WITH LOGIN PASSWORD '${builtins.readFile config.age.secrets.database-password.path}' CREATEDB;
      CREATE DATABASE nixos;
      GRANT ALL PRIVILEGES ON DATABASE nixos TO nixos;
    '';
  };

  # Open firewall port for PostgreSQL
  networking.firewall.allowedTCPPorts = [5432];

  # Add a custom message to the login banner
  environment.etc."issue.d/postgresql-info.txt".text = ''
    PostgreSQL is running on port 5432
    Default database: nixos
    Default credentials: nixos/[secure-password]
  '';
}
