-- Index product foreign keys for joins and parent-row updates/deletes.
create index if not exists "mse_fk_assets_1" on "plantops"."assets" ("created_by");
create index if not exists "mse_fk_condition_observations_1" on "plantops"."condition_observations" ("asset_id");
create index if not exists "mse_fk_condition_observations_2" on "plantops"."condition_observations" ("created_by");
create index if not exists "mse_fk_condition_observations_3" on "plantops"."condition_observations" ("asset_id", "organization_id");
create index if not exists "mse_fk_organizations_1" on "plantops"."organizations" ("created_by");
create index if not exists "mse_fk_spare_parts_1" on "plantops"."spare_parts" ("created_by");
create index if not exists "mse_fk_work_orders_1" on "plantops"."work_orders" ("asset_id", "organization_id");
create index if not exists "mse_fk_work_orders_2" on "plantops"."work_orders" ("asset_id");
create index if not exists "mse_fk_work_orders_3" on "plantops"."work_orders" ("created_by");
create index if not exists "mse_fk_work_orders_4" on "plantops"."work_orders" ("updated_by");

