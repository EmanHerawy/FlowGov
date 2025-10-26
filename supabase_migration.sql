-- FlowGov Database Schema Migration
-- Run this in your Supabase SQL Editor

-- Create custom enum type for voting NFT modes
CREATE TYPE voting_nft_modes AS ENUM (
  'no-nfts',
  'nft-holders',
  'nft-donators',
  'token-holders'
);

-- Create users table
CREATE TABLE IF NOT EXISTS users (
  address TEXT PRIMARY KEY
);

-- Create projects table
CREATE TABLE IF NOT EXISTS projects (
  project_id TEXT PRIMARY KEY,
  owner TEXT NOT NULL REFERENCES users(address),
  name TEXT,
  description TEXT,
  long_description TEXT,
  logo TEXT,
  banner_image TEXT,
  website TEXT,
  twitter TEXT,
  discord TEXT,
  contract_address TEXT,
  token_symbol TEXT,
  network TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create events table
CREATE TABLE IF NOT EXISTS events (
  id SERIAL PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(project_id),
  type TEXT NOT NULL,
  data JSONB,
  transaction_id TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(project_id),
  user_address TEXT NOT NULL REFERENCES users(address)
);

-- Create price_api table
CREATE TABLE IF NOT EXISTS price_api (
  id SERIAL PRIMARY KEY,
  price NUMERIC NOT NULL
);

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  wallet_address TEXT PRIMARY KEY,
  user_name TEXT NOT NULL,
  avatar_url TEXT,
  use_find BOOLEAN NOT NULL
);

-- Create rankings table
CREATE TABLE IF NOT EXISTS rankings (
  project_id TEXT PRIMARY KEY REFERENCES projects(project_id),
  total_funding NUMERIC NOT NULL DEFAULT 0,
  week_funding NUMERIC,
  num_holders NUMERIC,
  num_participants NUMERIC,
  num_proposals NUMERIC,
  treasury_value NUMERIC,
  tvl NUMERIC,
  total_supply NUMERIC,
  max_supply NUMERIC,
  price NUMERIC,
  volume_24h NUMERIC,
  liquidity_amount NUMERIC,
  nft_count NUMERIC,
  payment_currency TEXT,
  numbers JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create user_funding table
CREATE TABLE IF NOT EXISTS user_funding (
  id SERIAL PRIMARY KEY,
  address TEXT NOT NULL,
  project_id TEXT REFERENCES projects(project_id),
  amount NUMERIC,
  num_nfts NUMERIC
);

-- Create voting_rounds table
CREATE TABLE IF NOT EXISTS voting_rounds (
  id SERIAL PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(project_id),
  name TEXT NOT NULL,
  description TEXT,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ NOT NULL,
  nft_mode voting_nft_modes NOT NULL DEFAULT 'no-nfts',
  required_nft_collection_id TEXT,
  linked_action_type TEXT,
  linked_action_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create voting_options table
CREATE TABLE IF NOT EXISTS voting_options (
  id SERIAL PRIMARY KEY,
  voting_round_id INTEGER NOT NULL REFERENCES voting_rounds(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  option_number INTEGER NOT NULL
);

-- Create votes table
CREATE TABLE IF NOT EXISTS votes (
  id SERIAL PRIMARY KEY,
  voting_round_id INTEGER NOT NULL REFERENCES voting_rounds(id) ON DELETE CASCADE,
  wallet_address TEXT NOT NULL,
  selected_option INTEGER NOT NULL REFERENCES voting_options(id),
  amount_of_tokens NUMERIC,
  nft_uuids JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_events_project_id ON events(project_id);
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
CREATE INDEX IF NOT EXISTS idx_notifications_project_id ON notifications(project_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_address ON notifications(user_address);
CREATE INDEX IF NOT EXISTS idx_user_funding_project_id ON user_funding(project_id);
CREATE INDEX IF NOT EXISTS idx_user_funding_address ON user_funding(address);
CREATE INDEX IF NOT EXISTS idx_voting_rounds_project_id ON voting_rounds(project_id);
CREATE INDEX IF NOT EXISTS idx_voting_options_voting_round_id ON voting_options(voting_round_id);
CREATE INDEX IF NOT EXISTS idx_votes_voting_round_id ON votes(voting_round_id);
CREATE INDEX IF NOT EXISTS idx_votes_wallet_address ON votes(wallet_address);

-- Create database functions
CREATE OR REPLACE FUNCTION save_fund(
  _project_id TEXT,
  _usd_amount NUMERIC,
  _transaction_id TEXT,
  _data JSONB,
  _type TEXT,
  _funder TEXT
) RETURNS VOID AS $$
BEGIN
  -- Insert or update user
  INSERT INTO users (address) VALUES (_funder)
  ON CONFLICT (address) DO NOTHING;
  
  -- Insert event
  INSERT INTO events (project_id, type, data, transaction_id)
  VALUES (_project_id, _type, _data, _transaction_id);
  
  -- Insert or update user_funding
  INSERT INTO user_funding (address, project_id, amount)
  VALUES (_funder, _project_id, _usd_amount)
  ON CONFLICT DO NOTHING;
  
  -- Update rankings
  INSERT INTO rankings (project_id, total_funding)
  VALUES (_project_id, _usd_amount)
  ON CONFLICT (project_id) 
  DO UPDATE SET total_funding = rankings.total_funding + _usd_amount;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION save_fund_without_event(
  _project_id TEXT,
  _usd_amount NUMERIC,
  _funder TEXT
) RETURNS VOID AS $$
BEGIN
  -- Insert or update user
  INSERT INTO users (address) VALUES (_funder)
  ON CONFLICT (address) DO NOTHING;
  
  -- Insert or update user_funding
  INSERT INTO user_funding (address, project_id, amount)
  VALUES (_funder, _project_id, _usd_amount)
  ON CONFLICT DO NOTHING;
  
  -- Update rankings
  INSERT INTO rankings (project_id, total_funding)
  VALUES (_project_id, _usd_amount)
  ON CONFLICT (project_id) 
  DO UPDATE SET total_funding = rankings.total_funding + _usd_amount;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION save_nft_fund(
  _project_id TEXT,
  _type TEXT,
  _data JSONB,
  _transaction_id TEXT,
  _funder TEXT,
  _amount NUMERIC
) RETURNS VOID AS $$
BEGIN
  -- Insert or update user
  INSERT INTO users (address) VALUES (_funder)
  ON CONFLICT (address) DO NOTHING;
  
  -- Insert event
  INSERT INTO events (project_id, type, data, transaction_id)
  VALUES (_project_id, _type, _data, _transaction_id);
  
  -- Insert or update user_funding
  INSERT INTO user_funding (address, project_id, num_nfts)
  VALUES (_funder, _project_id, _amount)
  ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Enable Row Level Security (RLS) - Optional but recommended
-- Uncomment if you want to enable RLS
-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE events ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE price_api ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE rankings ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE user_funding ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE voting_rounds ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE voting_options ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE votes ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access (if RLS is enabled)
-- CREATE POLICY "Public read access" ON projects FOR SELECT USING (true);
-- CREATE POLICY "Public read access" ON voting_rounds FOR SELECT USING (true);
-- CREATE POLICY "Public read access" ON voting_options FOR SELECT USING (true);
-- CREATE POLICY "Public read access" ON votes FOR SELECT USING (true);
