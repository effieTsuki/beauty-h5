-- ============================================================
-- 护肤妆造 H5 · Supabase 初始化脚本
-- 用法：Supabase Dashboard -> SQL Editor -> 整段粘贴 -> Run
-- 可与衣橱 H5 共用同一个 Supabase 项目（表/桶均独立，互不影响）
-- ============================================================

-- 1. 建表：美妆
create table if not exists public.cosmetics (
  id           uuid primary key default gen_random_uuid(),
  owner        text not null default '',          -- 设备标识，用于数据隔离
  name         text not null,                     -- 名称
  brand        text,                              -- 品牌
  category     text not null default '其他',       -- 分类：洁面/爽肤水/精华/乳液/面霜/眼霜/防晒/面膜/卸妆/底妆/口红/眼妆/香氛/身体护理/美发/工具/其他（text 字段，无枚举约束，可自由扩展）
  capacity     text,                              -- 容量规格：30ml / 50g / 10片 等
  shade        text,                              -- 色号：01 / W03 / 小辣椒
  color        text,                              -- 颜色（hex 色值）
  skin         text not null default '通用',       -- 适用肤质：油皮/干皮/混合/敏感/通用
  usage_time   text[] not null default '{}',      -- 使用时段：早/晚
  price        numeric(12,2) not null default 0,  -- 金额（元）
  purchased_at date,                              -- 购入时间
  opened_at    date,                              -- 开封日期（算保质期用）
  pao_months   int,                              -- 开封后建议用完月数：6/12/24/36（PAO）
  platform     text,                              -- 购入渠道：淘宝/京东/拼多多/唯品会/抖音商城/免税店/代购/专柜/线下门店/其他
  image_url    text,                              -- 图片公开 URL
  note         text,                              -- 备注
  created_at   timestamptz not null default now()
);

-- 索引（按 owner 隔离，排序/筛选更快）
create index if not exists cosmetics_owner_idx    on public.cosmetics (owner);
create index if not exists cosmetics_category_idx on public.cosmetics (owner, category);
create index if not exists cosmetics_opened_idx   on public.cosmetics (owner, opened_at);

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
