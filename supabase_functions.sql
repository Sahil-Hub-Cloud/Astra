-- Astra Emergency Network - Database Schema & Functions
-- Updated for Production Use

-- Enable PostGIS extension for spatial operations
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable pg_cron extension for automated cleanup
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 1. INCIDENTS TABLE
-- Stores all emergency incidents with location data
CREATE TABLE IF NOT EXISTS incidents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    latitude DECIMAL(8,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    incident_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'medium',
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    reported_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    location GEOGRAPHY(Point, 4326),
    emergency_contacts JSONB,
    user_id UUID REFERENCES auth.users(id)
);

-- Index for fast spatial queries
CREATE INDEX IF NOT EXISTS idx_incidents_location ON incidents USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_incidents_reported_at ON incidents (reported_at);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents (status);

-- 2. EMERGENCY CONTACTS TABLE
-- Stores user's emergency contacts
CREATE TABLE IF NOT EXISTS emergency_contacts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    relationship VARCHAR(50),
    priority INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for user-specific queries
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user ON emergency_contacts (user_id);

-- 3. USERS TABLE
-- Custom user profiles extending auth.users
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    phone_number VARCHAR(15) UNIQUE,
    role VARCHAR(20) DEFAULT 'user',
    is_responder BOOLEAN DEFAULT false,
    is_admin BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for phone number lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_phone ON user_profiles (phone_number);

-- 4. POLICE ALERTS TABLE
-- Stores police alerts and notifications
CREATE TABLE IF NOT EXISTS police_alerts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    incident_id UUID REFERENCES incidents(id) ON DELETE SET NULL,
    alert_type VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    location GEOGRAPHY(Point, 4326),
    latitude DECIMAL(8,6),
    longitude DECIMAL(9,6),
    priority VARCHAR(20) DEFAULT 'medium',
    status VARCHAR(20) DEFAULT 'pending',
    assigned_officer_id UUID,
    responded_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for police alerts
CREATE INDEX IF NOT EXISTS idx_police_alerts_location ON police_alerts USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_police_alerts_status ON police_alerts (status);

-- 5. INCIDENT REPORTS TABLE
-- Stores detailed incident reports
CREATE TABLE IF NOT EXISTS incident_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    reporter_id UUID REFERENCES auth.users(id),
    report_title VARCHAR(200) NOT NULL,
    report_details TEXT,
    media_urls TEXT[],
    severity_rating INTEGER CHECK (severity_rating BETWEEN 1 AND 5),
    resolution_status VARCHAR(20) DEFAULT 'open',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for incident reports
CREATE INDEX IF NOT EXISTS idx_incident_reports_incident ON incident_reports (incident_id);

-- 6. CAMPUS SECURITY TABLE
-- Stores campus security posts and availability
CREATE TABLE IF NOT EXISTS campus_security (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    location_name VARCHAR(200) NOT NULL,
    location GEOGRAPHY(Point, 4326),
    latitude DECIMAL(8,6),
    longitude DECIMAL(9,6),
    contact_number VARCHAR(15),
    is_available BOOLEAN DEFAULT true,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    availability_radius INTEGER DEFAULT 500, -- meters
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for campus security
CREATE INDEX IF NOT EXISTS idx_campus_security_location ON campus_security USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_campus_security_availability ON campus_security (is_available);

-- 7. ACTION TAKEN TABLE
-- Tracks actions taken on incidents
CREATE TABLE IF NOT EXISTS action_taken (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id),
    action_type VARCHAR(50) NOT NULL,
    action_details TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for actions taken
CREATE INDEX IF NOT EXISTS idx_action_taken_incident ON action_taken (incident_id);

-- 8. USER SESSIONS TABLE
-- Tracks user sessions and device information
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id VARCHAR(100),
    device_type VARCHAR(50),
    ip_address INET,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- FUNCTION 1: Create incident with automatic location indexing
CREATE OR REPLACE FUNCTION create_incident_with_location(
    p_latitude DECIMAL,
    p_longitude DECIMAL,
    p_incident_type VARCHAR,
    p_severity VARCHAR DEFAULT 'medium',
    p_description TEXT DEFAULT '',
    p_status VARCHAR DEFAULT 'active',
    p_emergency_contacts JSONB DEFAULT '[]'
)
RETURNS TABLE (
    id UUID,
    reported_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
AS $$
DECLARE
    new_incident_id UUID;
BEGIN
    INSERT INTO incidents (
        latitude, longitude, incident_type, severity, 
        description, status, emergency_contacts, location
    ) VALUES (
        p_latitude, p_longitude, p_incident_type, p_severity,
        p_description, p_status, p_emergency_contacts,
        ST_SetSRID(ST_Point(p_longitude, p_latitude), 4326)::GEOGRAPHY
    )
    RETURNING incidents.id INTO new_incident_id;

    RETURN QUERY SELECT new_incident_id, NOW();
END;
$$;

-- FUNCTION 2: Get nearby incidents within radius
CREATE OR REPLACE FUNCTION get_nearby_incidents(
    p_lat DECIMAL,
    p_lng DECIMAL,
    p_radius_meters INTEGER DEFAULT 1000,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    latitude DECIMAL,
    longitude DECIMAL,
    incident_type VARCHAR,
    severity VARCHAR,
    description TEXT,
    status VARCHAR,
    reported_at TIMESTAMP WITH TIME ZONE,
    distance_meters NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id,
        i.latitude,
        i.longitude,
        i.incident_type,
        i.severity,
        i.description,
        i.status,
        i.reported_at,
        ST_Distance(i.location, ST_SetSRID(ST_Point(p_lng, p_lat), 4326)::GEOGRAPHY)::NUMERIC AS distance_meters
    FROM incidents i
    WHERE i.status = 'active'
        AND ST_DWithin(i.location, ST_SetSRID(ST_Point(p_lng, p_lat), 4326)::GEOGRAPHY, p_radius_meters)
    ORDER BY distance_meters ASC
    LIMIT p_limit;
END;
$$;

-- FUNCTION 3: Update incident status
CREATE OR REPLACE FUNCTION update_incident_status(
    p_incident_id UUID,
    p_status VARCHAR
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    affected_rows INTEGER;
BEGIN
    UPDATE incidents 
    SET status = p_status, updated_at = NOW()
    WHERE id = p_incident_id;
    
    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    
    RETURN affected_rows > 0;
END;
$$;

-- FUNCTION 4: Get incident statistics (Required by astra_backend.dart)
CREATE OR REPLACE FUNCTION get_incident_stats()
RETURNS TABLE (
    total_active INTEGER,
    total_resolved INTEGER,
    recent_24h INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*)::INTEGER FROM incidents WHERE status = 'active'),
        (SELECT COUNT(*)::INTEGER FROM incidents WHERE status = 'resolved'),
        (SELECT COUNT(*)::INTEGER FROM incidents WHERE reported_at > NOW() - INTERVAL '24 hours');
END;
$$;

-- FUNCTION 5: Get user's emergency contacts
CREATE OR REPLACE FUNCTION get_user_emergency_contacts(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    name VARCHAR,
    phone_number VARCHAR,
    relationship VARCHAR,
    priority INTEGER,
    is_active BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ec.id,
        ec.name,
        ec.phone_number,
        ec.relationship,
        ec.priority,
        ec.is_active
    FROM emergency_contacts ec
    WHERE ec.user_id = p_user_id AND ec.is_active = true
    ORDER BY ec.priority ASC;
END;
$$;

-- RLS POLICIES
-- Enable RLS on all tables
ALTER TABLE incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE police_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE incident_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE campus_security ENABLE ROW LEVEL SECURITY;
ALTER TABLE action_taken ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- POLICIES FOR INCIDENTS TABLE
-- Users can only view their own incidents directly to protect privacy.
-- Global/Nearby monitoring is handled by the SECURE RPC functions or Realtime with filters.
CREATE POLICY "Users can view own incidents" ON incidents
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

-- Users can insert their own incidents
CREATE POLICY "Users can insert their own incidents" ON incidents
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Users can update their own incidents
CREATE POLICY "Users can update their own incidents" ON incidents
FOR UPDATE TO authenticated
USING (auth.uid() = user_id);

-- POLICIES FOR EMERGENCY_CONTACTS TABLE
-- Users can view their own contacts
CREATE POLICY "Users can view own contacts" ON emergency_contacts
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

-- Users can insert their own contacts
CREATE POLICY "Users can insert own contacts" ON emergency_contacts
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Users can update their own contacts
CREATE POLICY "Users can update own contacts" ON emergency_contacts
FOR UPDATE TO authenticated
USING (auth.uid() = user_id);

-- Users can delete their own contacts
CREATE POLICY "Users can delete own contacts" ON emergency_contacts
FOR DELETE TO authenticated
USING (auth.uid() = user_id);

-- POLICIES FOR USER_PROFILES TABLE
-- Users can view their own profile
CREATE POLICY "Users can view own profile" ON user_profiles
FOR SELECT TO authenticated
USING (auth.uid() = id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile" ON user_profiles
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON user_profiles
FOR UPDATE TO authenticated
USING (auth.uid() = id);

-- POLICIES FOR POLICE_ALERTS TABLE
-- Allow authenticated users to view police alerts
CREATE POLICY "Users can view police alerts" ON police_alerts
FOR SELECT TO authenticated
USING (true);

-- Users can insert police alerts (admin/responder only)
CREATE POLICY "Admins and responders can insert police alerts" ON police_alerts
FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() AND (is_admin = true OR is_responder = true)
    )
);

-- POLICIES FOR INCIDENT_REPORTS TABLE
-- Users can view reports for incidents they have access to
CREATE POLICY "Users can view incident reports" ON incident_reports
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM incidents 
        WHERE incidents.id = incident_reports.incident_id
    )
);

-- Users can insert their own incident reports
CREATE POLICY "Users can insert incident reports" ON incident_reports
FOR INSERT TO authenticated
WITH CHECK (reporter_id = auth.uid());

-- POLICIES FOR CAMPUS_SECURITY TABLE
-- Everyone can view campus security (public info)
CREATE POLICY "Everyone can view campus security" ON campus_security
FOR SELECT TO authenticated
USING (true);

-- Admins can manage campus security
CREATE POLICY "Admins can manage campus security" ON campus_security
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() AND is_admin = true
    )
);

-- POLICIES FOR ACTION_TAKEN TABLE
-- Users can view actions for incidents they have access to
CREATE POLICY "Users can view actions taken" ON action_taken
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM incidents 
        WHERE incidents.id = action_taken.incident_id
    )
);

-- Users can insert their own actions
CREATE POLICY "Users can insert own actions" ON action_taken
FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

-- POLICIES FOR USER_SESSIONS TABLE
-- Users can view their own sessions
CREATE POLICY "Users can view own sessions" ON user_sessions
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

-- Users can insert their own session
CREATE POLICY "Users can insert own session" ON user_sessions
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

-- TRIGGER: Automatically create user profile when user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, phone_number)
    VALUES (NEW.id, NEW.phone);
    RETURN NEW;
END;
$$;

-- Trigger for new user signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- RLS for auth.users - restrict access
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own data" ON auth.users
FOR SELECT TO authenticated
USING (auth.uid() = id);

-- Automated cleanup job to remove old inactive incidents
SELECT cron.schedule(
    'cleanup-old-incidents',
    '0 2 * * *',  -- Daily at 2 AM
    $$DELETE FROM incidents WHERE status = 'resolved' AND updated_at < NOW() - INTERVAL '30 days'$$
);