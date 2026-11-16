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

-- Limite de 50 inscrições.
-- O trava garante que duas inscrições ao mesmo tempo não passem do limite.
create or replace function public.limite_inscricoes_picnic()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform pg_advisory_xact_lock(hashtext('inscricoes_picnic'));
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
  select greatest(50 - count(*), 0)::int from public.inscricoes_picnic;
$$;

revoke all on function public.vagas_picnic() from public;
grant execute on function public.vagas_picnic() to anon, authenticated;
