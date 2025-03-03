-- Drop all tables first (in correct dependency order)
DROP TABLE IF EXISTS metrics, allocations, instance_logs, audit_logs, api_keys, config_vars, 
    deployment_logs, deployments, builds, instances, domains, apps, 
    orgmember, permissions_role, role_user, permissions, roles, orgs, 
    users, regions;

-- Create independent tables first (no foreign keys)
CREATE TABLE users (
    id BIGINT NOT NULL AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL,
    salt VARCHAR(255) NOT NULL,
    active TINYINT(1) DEFAULT 0,
    last_login_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE roles (
    id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE permissions (
    id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    resource_type VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE regions (
    id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL UNIQUE,
    provider ENUM('kubernetes', 'docker', 'custom') NOT NULL,
    status ENUM('active', 'maintenance', 'offline') DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE orgs (
    id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create tables with single foreign key dependencies
CREATE TABLE permissions_role (
    permissions_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    PRIMARY KEY (permissions_id, role_id),
    FOREIGN KEY (permissions_id) REFERENCES permissions(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE role_user (
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    PRIMARY KEY (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE orgmember (
    id BIGINT NOT NULL AUTO_INCREMENT,
    org_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    role ENUM('owner', 'admin', 'member') DEFAULT 'member',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY unique_org_user (org_id, user_id),
    FOREIGN KEY (org_id) REFERENCES orgs(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE api_keys (
    id BIGINT NOT NULL AUTO_INCREMENT,
    org_id BIGINT NOT NULL,
    name VARCHAR(255) NOT NULL,
    key_hash VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (org_id) REFERENCES orgs(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE allocations (
    id BIGINT NOT NULL AUTO_INCREMENT,
    cpu DOUBLE NOT NULL,
    memory DOUBLE NOT NULL,
    uplink DOUBLE NOT NULL,
    downlink DOUBLE NOT NULL,
    disk DOUBLE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create application-related tables
CREATE TABLE apps (
    id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    org_id BIGINT NOT NULL,
    git_repo VARCHAR(255),
    git_branch VARCHAR(255) DEFAULT 'main',
    container_image_url VARCHAR(255),
    default_allocation_id BIGINT,
    region_id BIGINT,
    maintenance_mode TINYINT(1) DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY unique_name_org (name, org_id),
    FOREIGN KEY (org_id) REFERENCES orgs(id) ON DELETE CASCADE,
    FOREIGN KEY (default_allocation_id) REFERENCES allocations(id),
    FOREIGN KEY (region_id) REFERENCES regions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE instances (
    id BIGINT NOT NULL AUTO_INCREMENT,
    app_id BIGINT NOT NULL,
    instance_type VARCHAR(255) NOT NULL,
    status ENUM('provisioning', 'running', 'stopping', 'stopped', 'terminated', 'failed') DEFAULT 'provisioning',
    container_id VARCHAR(255),
    allocation_id BIGINT,
    node_name VARCHAR(255),
    instance_status ENUM('running', 'stopped', 'terminated', 'failed') DEFAULT 'running',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE,
    FOREIGN KEY (allocation_id) REFERENCES allocations(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE domains (
    id BIGINT NOT NULL AUTO_INCREMENT,
    app_id BIGINT NOT NULL,
    name VARCHAR(255) NOT NULL UNIQUE,
    ssl_enabled TINYINT(1) DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE builds (
    id BIGINT NOT NULL AUTO_INCREMENT,
    app_id BIGINT NOT NULL,
    source_version VARCHAR(255),
    status ENUM('pending', 'building', 'succeeded', 'failed') DEFAULT 'pending',
    started_at DATETIME,
    completed_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE deployments (
    id BIGINT NOT NULL AUTO_INCREMENT,
    app_id BIGINT NOT NULL,
    build_id BIGINT NOT NULL,
    status ENUM('pending', 'in_progress', 'deployed', 'failed') DEFAULT 'pending',
    started_at DATETIME,
    completed_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE,
    FOREIGN KEY (build_id) REFERENCES builds(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE config_vars (
    id BIGINT NOT NULL AUTO_INCREMENT,
    app_id BIGINT NOT NULL,
    `key` VARCHAR(255) NOT NULL,
    value TEXT,
    is_secret TINYINT(1) DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY unique_app_key (app_id, `key`),
    FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create monitoring and logging tables
CREATE TABLE metrics (
    id BIGINT NOT NULL AUTO_INCREMENT,
    instance_id BIGINT NOT NULL,
    metric_name VARCHAR(255) NOT NULL,
    metric_value DOUBLE NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (instance_id) REFERENCES instances(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE instance_logs (
    id BIGINT NOT NULL AUTO_INCREMENT,
    instance_id BIGINT NOT NULL,
    log_type ENUM('app', 'system', 'deployment') NOT NULL,
    message TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (instance_id) REFERENCES instances(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE audit_logs (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT,
    org_id BIGINT,
    action VARCHAR(255) NOT NULL,
    resource_type VARCHAR(255) NOT NULL,
    resource_id VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (org_id) REFERENCES orgs(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create all indexes after table creation
ALTER TABLE users ADD INDEX idx_users_email (email);
ALTER TABLE apps ADD INDEX idx_apps_name (name);
ALTER TABLE apps ADD INDEX idx_apps_org_id (org_id);
ALTER TABLE instances ADD INDEX idx_instances_app_id (app_id);
ALTER TABLE config_vars ADD INDEX idx_config_vars_app_id (app_id);
ALTER TABLE metrics ADD INDEX idx_metrics_instance_id_timestamp (instance_id, timestamp, metric_name);
ALTER TABLE instance_logs ADD INDEX idx_logs_instance_id_timestamp (instance_id, timestamp);
ALTER TABLE audit_logs ADD INDEX idx_audit_logs_created_at (created_at);
ALTER TABLE deployments ADD INDEX idx_deployments_app_id (app_id);
ALTER TABLE orgmember ADD INDEX idx_orgmember_org_id (org_id);
ALTER TABLE orgmember ADD INDEX idx_orgmember_user_id (user_id);
