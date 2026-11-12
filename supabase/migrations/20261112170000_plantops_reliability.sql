-- PlantOps isolated schema. Apply only to the MSE Product Suite project.
create schema if not exists plantops;
revoke all on schema plantops from anon, public;
grant usage on schema plantops to authenticated;

create table if not exists plantops.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 100),
  region text not null default '' check (char_length(region) <= 120),
  team_code text not null unique default upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 10)),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists plantops.organization_members (
  organization_id uuid not null references plantops.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);
create index if not exists plantops_members_user_idx on plantops.organization_members(user_id, organization_id);

create table if not exists plantops.assets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references plantops.organizations(id) on delete cascade,
  asset_tag text not null check (char_length(asset_tag) between 1 and 60),
  name text not null check (char_length(name) between 1 and 140),
  asset_class text not null check (char_length(asset_class) <= 80),
  location text not null default '' check (char_length(location) <= 140),
  criticality smallint not null default 3 check (criticality between 1 and 5),
  manufacturer text not null default '' check (char_length(manufacturer) <= 100),
  model text not null default '' check (char_length(model) <= 100),
  commissioned_on date,
  status text not null default 'operating' check (status in ('operating', 'watch', 'offline')),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique (organization_id, asset_tag),
  unique (id, organization_id)
);
create index if not exists plantops_assets_org_idx on plantops.assets(organization_id, asset_tag);

create table if not exists plantops.condition_observations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references plantops.organizations(id) on delete cascade,
  asset_id uuid not null references plantops.assets(id) on delete cascade,
  vibration_mm_s numeric(9,2) check (vibration_mm_s is null or vibration_mm_s >= 0),
  temperature_c numeric(8,2) check (temperature_c is null or temperature_c between -100 and 1000),
  pressure_bar numeric(9,2),
  runtime_hours numeric(12,2) check (runtime_hours is null or runtime_hours >= 0),
  note text not null default '' check (char_length(note) <= 500),
  observed_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  constraint plantops_observation_asset_org_fk foreign key (asset_id, organization_id) references plantops.assets(id, organization_id) on delete cascade
);
create index if not exists plantops_observations_org_time_idx on plantops.condition_observations(organization_id, observed_at desc);

create table if not exists plantops.work_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references plantops.organizations(id) on delete cascade,
  asset_id uuid not null references plantops.assets(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 140),
  priority text not null default 'planned' check (priority in ('planned', 'routine', 'urgent', 'critical')),
  status text not null default 'planned' check (status in ('planned', 'in_progress', 'completed')),
  due_at timestamptz,
  notes text not null default '' check (char_length(notes) <= 700),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint plantops_work_order_asset_org_fk foreign key (asset_id, organization_id) references plantops.assets(id, organization_id) on delete cascade
);
create index if not exists plantops_work_org_status_idx on plantops.work_orders(organization_id, status, due_at);

create table if not exists plantops.spare_parts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references plantops.organizations(id) on delete cascade,
  part_number text not null check (char_length(part_number) between 1 and 60),
  name text not null check (char_length(name) between 1 and 120),
  quantity_on_hand integer not null default 0 check (quantity_on_hand between 0 and 1000000),
  reorder_point integer not null default 0 check (reorder_point between 0 and 1000000),
  lead_time_days integer not null default 0 check (lead_time_days between 0 and 3650),
  unit text not null default 'units' check (char_length(unit) between 1 and 24),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique (organization_id, part_number)
);
create index if not exists plantops_parts_org_idx on plantops.spare_parts(organization_id, name);

create or replace function plantops.is_org_member(p_org_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from plantops.organization_members m where m.organization_id = p_org_id and m.user_id = (select auth.uid()));
$$;
revoke all on function plantops.is_org_member(uuid) from public, anon;
grant execute on function plantops.is_org_member(uuid) to authenticated;

create or replace function plantops.create_organization(p_name text, p_region text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if char_length(trim(p_name)) not between 2 and 100 then raise exception 'Organization name must be 2 to 100 characters'; end if;
  insert into plantops.organizations(name, region, created_by) values (trim(p_name), coalesce(trim(p_region), ''), auth.uid()) returning id into v_id;
  insert into plantops.organization_members(organization_id, user_id, role) values (v_id, auth.uid(), 'owner');
  return v_id;
end;
$$;
revoke all on function plantops.create_organization(text,text) from public, anon;
grant execute on function plantops.create_organization(text,text) to authenticated;

create or replace function plantops.join_organization(p_team_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select id into v_id from plantops.organizations where team_code = upper(trim(p_team_code));
  if v_id is null then raise exception 'Team code not found'; end if;
  insert into plantops.organization_members(organization_id, user_id) values (v_id, auth.uid()) on conflict do nothing;
  return v_id;
end;
$$;
revoke all on function plantops.join_organization(text) from public, anon;
grant execute on function plantops.join_organization(text) to authenticated;

create or replace function plantops.adjust_part_stock(p_part_id uuid, p_delta integer)
returns void language plpgsql security definer set search_path = '' as $$
declare v_org uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_delta not between -1000000 and 1000000 then raise exception 'Invalid stock adjustment'; end if;
  select organization_id into v_org from plantops.spare_parts where id = p_part_id for update;
  if v_org is null or not plantops.is_org_member(v_org) then raise exception 'Part unavailable'; end if;
  update plantops.spare_parts set quantity_on_hand = quantity_on_hand + p_delta
    where id = p_part_id and quantity_on_hand + p_delta between 0 and 1000000;
  if not found then raise exception 'Stock adjustment would exceed the allowed range'; end if;
end;
$$;
revoke all on function plantops.adjust_part_stock(uuid,integer) from public, anon;
grant execute on function plantops.adjust_part_stock(uuid,integer) to authenticated;

alter table plantops.organizations enable row level security;
alter table plantops.organization_members enable row level security;
alter table plantops.assets enable row level security;
alter table plantops.condition_observations enable row level security;
alter table plantops.work_orders enable row level security;
alter table plantops.spare_parts enable row level security;

create policy "members can read their organizations" on plantops.organizations for select to authenticated using (plantops.is_org_member(id));
create policy "members can read their membership roster" on plantops.organization_members for select to authenticated using (plantops.is_org_member(organization_id));
create policy "members can read assets" on plantops.assets for select to authenticated using (plantops.is_org_member(organization_id));
create policy "members can add assets" on plantops.assets for insert to authenticated with check (plantops.is_org_member(organization_id) and created_by = auth.uid());
create policy "members can update assets" on plantops.assets for update to authenticated using (plantops.is_org_member(organization_id)) with check (plantops.is_org_member(organization_id));
create policy "members can read condition observations" on plantops.condition_observations for select to authenticated using (plantops.is_org_member(organization_id));
create policy "members can add condition observations" on plantops.condition_observations for insert to authenticated with check (plantops.is_org_member(organization_id) and created_by = auth.uid());
create policy "members can read work orders" on plantops.work_orders for select to authenticated using (plantops.is_org_member(organization_id));
create policy "members can add work orders" on plantops.work_orders for insert to authenticated with check (plantops.is_org_member(organization_id) and created_by = auth.uid());
create policy "members can update work orders" on plantops.work_orders for update to authenticated using (plantops.is_org_member(organization_id)) with check (plantops.is_org_member(organization_id));
create policy "members can read spare parts" on plantops.spare_parts for select to authenticated using (plantops.is_org_member(organization_id));
create policy "members can add spare parts" on plantops.spare_parts for insert to authenticated with check (plantops.is_org_member(organization_id) and created_by = auth.uid());

revoke all on all tables in schema plantops from anon, public;
grant select on plantops.organizations, plantops.organization_members, plantops.assets, plantops.condition_observations, plantops.work_orders, plantops.spare_parts to authenticated;
grant insert, update on plantops.assets, plantops.work_orders to authenticated;
grant insert on plantops.condition_observations, plantops.spare_parts to authenticated;
