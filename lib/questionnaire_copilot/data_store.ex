defmodule QuestionnaireCopilot.DataStore do
  @moduledoc """
  Dispatch module that routes to either the database-backed contexts
  or the in-memory demo session, based on the store tuple.

  Store is either `:db` or `{:demo, session_id}`.
  """

  alias QuestionnaireCopilot.{Vault, Questionnaires}
  alias QuestionnaireCopilot.Demo.Session

  # Vault operations

  def list_qa_pairs(:db), do: Vault.list_qa_pairs()
  def list_qa_pairs({:demo, sid}), do: Session.call(sid, :list_qa_pairs)

  def get_qa_pair!(:db, id), do: Vault.get_qa_pair!(id)
  def get_qa_pair!({:demo, sid}, id), do: Session.call(sid, {:get_qa_pair, id})

  def create_qa_pair(:db, attrs), do: Vault.create_qa_pair(attrs)
  def create_qa_pair({:demo, sid}, attrs), do: Session.call(sid, {:create_qa_pair, attrs})

  def update_qa_pair(:db, qa_pair, attrs), do: Vault.update_qa_pair(qa_pair, attrs)

  def update_qa_pair({:demo, sid}, qa_pair, attrs),
    do: Session.call(sid, {:update_qa_pair, qa_pair.id, attrs})

  def delete_qa_pair(:db, qa_pair), do: Vault.delete_qa_pair(qa_pair)
  def delete_qa_pair({:demo, sid}, qa_pair), do: Session.call(sid, {:delete_qa_pair, qa_pair.id})

  def change_qa_pair(store, qa_pair, attrs \\ %{})
  def change_qa_pair(:db, qa_pair, attrs), do: Vault.change_qa_pair(qa_pair, attrs)

  def change_qa_pair({:demo, sid}, qa_pair, attrs),
    do: Session.call(sid, {:change_qa_pair, qa_pair, attrs})

  def search_qa_pairs(:db, query), do: Vault.search_qa_pairs(query)
  def search_qa_pairs({:demo, sid}, query), do: Session.call(sid, {:search_qa_pairs, query})

  def search_and_filter(:db, search, tags), do: Vault.search_and_filter(search, tags)

  def search_and_filter({:demo, sid}, search, tags),
    do: Session.call(sid, {:search_and_filter, search, tags})

  def all_tags(:db), do: Vault.all_tags()
  def all_tags({:demo, sid}), do: Session.call(sid, :all_tags)

  def has_close_match?(:db, question), do: Vault.has_close_match?(question)

  def has_close_match?({:demo, sid}, question),
    do: Session.call(sid, {:has_close_match?, question})

  def import_csv(:db, content), do: Vault.import_csv(content)
  def import_csv({:demo, sid}, content), do: Session.call(sid, {:import_csv, content})

  def vault_to_csv(:db), do: Vault.to_csv()
  def vault_to_csv({:demo, sid}), do: Session.call(sid, :vault_to_csv)

  # Questionnaire operations

  def list_questionnaires(:db), do: Questionnaires.list_questionnaires()
  def list_questionnaires({:demo, sid}), do: Session.call(sid, :list_questionnaires)

  def get_questionnaire!(:db, id), do: Questionnaires.get_questionnaire!(id)
  def get_questionnaire!({:demo, sid}, id), do: Session.call(sid, {:get_questionnaire, id})

  def create_questionnaire(:db, attrs), do: Questionnaires.create_questionnaire(attrs)

  def create_questionnaire({:demo, sid}, attrs),
    do: Session.call(sid, {:create_questionnaire, attrs})

  def delete_questionnaire(:db, q), do: Questionnaires.delete_questionnaire(q)
  def delete_questionnaire({:demo, sid}, q), do: Session.call(sid, {:delete_questionnaire, q.id})

  def change_questionnaire(store, q, attrs \\ %{})
  def change_questionnaire(:db, q, attrs), do: Questionnaires.change_questionnaire(q, attrs)

  def change_questionnaire({:demo, sid}, q, attrs),
    do: Session.call(sid, {:change_questionnaire, q, attrs})

  def create_items_from_text(:db, q, text), do: Questionnaires.create_items_from_text(q, text)

  def create_items_from_text({:demo, sid}, q, text),
    do: Session.call(sid, {:create_items_from_text, q.id, text})

  def create_items_from_list(:db, q, questions),
    do: Questionnaires.create_items_from_list(q, questions)

  def create_items_from_list({:demo, sid}, q, questions),
    do: Session.call(sid, {:create_items_from_list, q.id, questions})

  def get_item!(:db, id), do: Questionnaires.get_item!(id)
  def get_item!({:demo, sid}, id), do: Session.call(sid, {:get_item, id})

  def update_item(:db, item, attrs), do: Questionnaires.update_item(item, attrs)

  def update_item({:demo, sid}, item, attrs),
    do: Session.call(sid, {:update_item, item.id, attrs})

  def questionnaire_to_csv(:db, q), do: Questionnaires.to_csv(q)
  def questionnaire_to_csv({:demo, sid}, q), do: Session.call(sid, {:questionnaire_to_csv, q.id})

  def progress(:db, q), do: Questionnaires.progress(q)
  def progress({:demo, sid}, q), do: Session.call(sid, {:progress, q})

  def maybe_mark_completed(:db, q), do: Questionnaires.maybe_mark_completed(q)
  def maybe_mark_completed({:demo, sid}, q), do: Session.call(sid, {:maybe_mark_completed, q})
end
