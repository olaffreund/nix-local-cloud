{
  pkgs,
  config,
  lib,
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

    # Instead of using initialScript, we'll use postStart to ensure the secret is available
    initialScript = null;
  };

  # Create a service extension that will set up the database after PostgreSQL starts
  systemd.services.postgresql = {
    postStart = lib.mkAfter ''
            # Wait for PostgreSQL to be ready
            until ${config.services.postgresql.package}/bin/pg_isready -h localhost; do
              sleep 1
            done

            # Extract the password from the age secret
            DB_PASSWORD=$(cat ${config.age.secrets.database-password.path})

            # Check if the role already exists to avoid errors on restarts
            if ! ${config.services.postgresql.package}/bin/psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='nixos'" | grep -q 1; then
              # Create the role and database
              ${config.services.postgresql.package}/bin/psql -U postgres <<EOF
      CREATE ROLE nixos WITH LOGIN PASSWORD '$DB_PASSWORD' CREATEDB;
      CREATE DATABASE nixos;
      GRANT ALL PRIVILEGES ON DATABASE nixos TO nixos;
      EOF
            fi
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
