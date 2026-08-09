defmodule Livedata.Projects.Methodology do
  use Ecto.Schema
  import Ecto.Changeset

  # @req: CRCF-19
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Minimal registry — the versioned, parametrised engine is #62.
  schema "methodologies" do
    field :name, :string
    field :reference, :string
    # @req: CRCF-20
    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(methodology, attrs) do
    methodology
    |> cast(attrs, [:name, :reference])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
