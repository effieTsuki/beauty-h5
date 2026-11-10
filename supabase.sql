-- ============================================================
-- 护肤妆造 H5 · Supabase 初始化脚本
-- 用法：Supabase Dashboard -> SQL Editor -> 整段粘贴 -> Run
-- 可与衣橱 H5 共用同一个 Supabase 项目（表/桶均独立，互不影响）
-- ★ 老库升级：已部署过的项目，重跑本文件即可无损升级
--   （自动补 opened / expire_date 两列并回填开封状态，历史数据不动）
-- ============================================================

-- 1. 建表：美妆（新库直接建全；老库因表已存在会跳过，走下方升级段）
create table if not exists public.cosmetics (
  id           uuid primary key default gen_random_uuid(),
  owner        text not null default '',          -- 设备标识，用于数据隔离
  name         text not null,                     -- 名称
  brand        text,                              -- 品牌（旧版字段，仅兼容历史数据，新表单不再填写）
  category     text not null default '其他',       -- 分类：洁面/爽肤水/精华/乳液/面霜/眼霜/防晒/面膜/卸妆/底妆/口红/眼妆/香氛/身体护理/美发/工具/其他（text 字段，无枚举约束，可自由扩展）
  capacity     text,                              -- 容量规格：30ml / 50g / 10片 等（手填）
  shade        text,                              -- 色号：01 / W03 / 小辣椒
  color        text,                              -- 颜色（hex 色值，旧版字段，仅兼容历史数据）
  skin         text not null default '通用',       -- 适用肤质（旧版字段，仅兼容历史数据）
  usage_time   text[] not null default '{}',      -- 使用时段（旧版字段，仅兼容历史数据）
  price        numeric(12,2) not null default 0,  -- 金额（元）
  purchased_at date,                              -- 购入时间
  opened       boolean not null default false,    -- 开封状态：未开封 / 已开封（显式选择）
  opened_at    date,                              -- 开封日期（选填）
  expire_date  date,                              -- 到期日期（填包装上的到期日，超期提醒按它算）
  platform     text,                              -- 购入渠道：淘宝/京东/拼多多/唯品会/抖音商城/免税店/代购/专柜/线下门店/其他
  image_url    text,                              -- 图片公开 URL
  note         text,                              -- 备注
  created_at   timestamptz not null default now()
);

-- 1b. 老库升级（幂等，可重复执行）：
--     2026-11 表单改版去掉「开封后建议用完(PAO)」，改为显式开封状态 + 到期日期
alter table public.cosmetics add column if not exists opened      boolean;
alter table public.cosmetics add column if not exists expire_date date;
-- 老数据回填：以前填过开封日期的视为已开封
update public.cosmetics set opened = (opened_at is not null) where opened is null;
alter table public.cosmetics alter column opened set default false;
alter table public.cosmetics alter column opened set not null;
-- 旧列 pao_months / color / skin / usage_time 在老库中保留不动（兼容历史数据），
-- 新库不再创建 pao_months。

-- 索引（按 owner 隔离，排序/筛选更快）
create index if not exists cosmetics_owner_idx    on public.cosmetics (owner);
create index if not exists cosmetics_category_idx on public.cosmetics (owner, category);
create index if not exists cosmetics_opened_idx   on public.cosmetics (owner, opened_at);
create index if not exists cosmetics_expire_idx   on public.cosmetics (owner, expire_date);

-- 给匿名角色授予读写权限（个人试用；前端用 owner 字段做逻辑隔离）
grant select, insert, update, delete on public.cosmetics to anon;

-- 行级安全（RLS）：若表已启用 RLS（Table Editor 常引导开启），需建放行策略
drop policy if exists "cosmetics_public_all" on public.cosmetics;
create policy "cosmetics_public_all"
  on public.cosmetics
  for all
  to anon
  using (true)
  with check (true);

-- ============================================================
-- 2. 图片存储桶（public：图片公开可访问）
-- ============================================================
insert into storage.buckets (id, name, public)
values ('cosmetics', 'cosmetics', true)
on conflict (id) do nothing;

-- 3. 存储权限：允许匿名上传/更新/删除 cosmetics 桶内的对象
-- 注意：SELECT 策略必不可少——本环境（Supabase PG）的 DELETE/UPDATE 要求
-- 目标行同时对 SELECT 策略可见，缺它会导致删除静默匹配 0 行（403/空数组）
drop policy if exists cosmetics_storage_public_select on storage.objects;
create policy cosmetics_storage_public_select
  on storage.objects for select to anon
  using (bucket_id = 'cosmetics');

drop policy if exists cosmetics_storage_public_insert on storage.objects;
create policy cosmetics_storage_public_insert
  on storage.objects for insert to anon
  with check (bucket_id = 'cosmetics');

drop policy if exists cosmetics_storage_public_update on storage.objects;
create policy cosmetics_storage_public_update
  on storage.objects for update to anon
  using (bucket_id = 'cosmetics');

drop policy if exists cosmetics_storage_public_delete on storage.objects;
create policy cosmetics_storage_public_delete
  on storage.objects for delete to anon
  using (bucket_id = 'cosmetics');
