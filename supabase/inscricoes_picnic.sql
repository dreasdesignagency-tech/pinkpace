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
