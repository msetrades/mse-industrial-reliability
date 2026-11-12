-- Evaluate auth.uid() once per statement instead of once per candidate row.
drop policy if exists "members can add assets" on plantops.assets;
create policy "members can add assets" on plantops.assets for insert to authenticated
  with check (plantops.is_org_member(organization_id) and created_by = (select auth.uid()));

drop policy if exists "members can add condition observations" on plantops.condition_observations;
create policy "members can add condition observations" on plantops.condition_observations for insert to authenticated
  with check (plantops.is_org_member(organization_id) and created_by = (select auth.uid()));

drop policy if exists "members can add work orders" on plantops.work_orders;
create policy "members can add work orders" on plantops.work_orders for insert to authenticated
  with check (plantops.is_org_member(organization_id) and created_by = (select auth.uid()));

drop policy if exists "members can add spare parts" on plantops.spare_parts;
create policy "members can add spare parts" on plantops.spare_parts for insert to authenticated
  with check (plantops.is_org_member(organization_id) and created_by = (select auth.uid()));
