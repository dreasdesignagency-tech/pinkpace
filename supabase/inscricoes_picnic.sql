-- Tabela das inscrições do Picnic Pink Pace.
-- Quem visita a página só consegue inserir. Ninguém de fora lê, altera ou apaga.
create table if not exists public.inscricoes_picnic (
  id bigint generated always as identity primary key,
  criado_em timestamptz not null default now(),
  nome text not null check (char_length(nome) between 2 and 120),
  whats text not null check (char_length(whats) between 8 and 30),
  grupo text check (char_length(grupo) <= 40),
  restricao text check (char_length(restricao) <= 1000),
  pergunta text check (char_length(pergunta) <= 1000)
);

alter table public.inscricoes_picnic enable row level security;

revoke all on public.inscricoes_picnic from anon, authenticated;
grant insert (nome, whats, grupo, restricao, pergunta) on public.inscricoes_picnic to anon;

drop policy if exists "visitantes podem se inscrever" on public.inscricoes_picnic;
create policy "visitantes podem se inscrever"
  on public.inscricoes_picnic for insert to anon
  with check (true);

-- Limite de 50 inscrições e prazo até o fim do dia 29/11 (horário de Brasília).
-- O trava garante que duas inscrições ao mesmo tempo não passem do limite.
create or replace function public.limite_inscricoes_picnic()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform pg_advisory_xact_lock(hashtext('inscricoes_picnic'));
  if now() >= timestamptz '2026-11-30 00:00:00-03' then
    raise exception 'inscricoes_prazo_encerrado' using errcode = 'P0001';
  end if;
  if (select count(*) from public.inscricoes_picnic) >= 50 then
    raise exception 'inscricoes_esgotadas' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists limite_inscricoes_picnic on public.inscricoes_picnic;
create trigger limite_inscricoes_picnic
  before insert on public.inscricoes_picnic
  for each row execute function public.limite_inscricoes_picnic();

revoke all on function public.limite_inscricoes_picnic() from public, anon, authenticated;

-- Quantas vagas ainda restam. A página consulta isso pra mostrar o aviso de esgotado.
-- Não expõe nenhum dado das inscritas, só o número.
create or replace function public.vagas_picnic()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case when now() >= timestamptz '2026-11-30 00:00:00-03' then 0
              else greatest(50 - count(*), 0)::int end
  from public.inscricoes_picnic;
$$;

revoke all on function public.vagas_picnic() from public;
grant execute on function public.vagas_picnic() to anon, authenticated;

-- Página /inscricoes: só contas listadas em pinkpace_admins leem e apagam inscrições.
create table if not exists public.pinkpace_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  criado_em timestamptz not null default now()
);
alter table public.pinkpace_admins enable row level security;
revoke all on public.pinkpace_admins from anon, authenticated;

create or replace function public.is_pinkpace_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.pinkpace_admins where user_id = auth.uid());
$$;
revoke all on function public.is_pinkpace_admin() from public, anon;
grant execute on function public.is_pinkpace_admin() to authenticated;

grant select, delete on public.inscricoes_picnic to authenticated;

drop policy if exists "admins da pink pace leem" on public.inscricoes_picnic;
create policy "admins da pink pace leem"
  on public.inscricoes_picnic for select to authenticated
  using (public.is_pinkpace_admin());

drop policy if exists "admins da pink pace apagam" on public.inscricoes_picnic;
create policy "admins da pink pace apagam"
  on public.inscricoes_picnic for delete to authenticated
  using (public.is_pinkpace_admin());

-- Pra dar acesso a alguém que já tem login no projeto:
-- insert into public.pinkpace_admins (user_id) select id from auth.users where email = 'email@exemplo.com';
