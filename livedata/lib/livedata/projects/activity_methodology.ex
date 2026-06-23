defmodule Livedata.Projects.ActivityMethodology do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type :binary_id

  schema "activity_methodologies" do
    # @req: CRCF-35
    field :activity_id, :binary_id, primary_key: true
    # @req: CRCF-35
    field :methodology_id, :binary_id, primary_key: true
    # @req: CRCF-20
    field :applied_at, :utc_datetime_usec
  end

  @doc false
  def changeset(activity_methodology, activity_id, attrs) do
    activity_methodology
    |> cast(attrs, [:methodology_id, :applied_at])
    |> put_change(:activity_id, activity_id)
    |> validate_required([:activity_id, :methodology_id, :applied_at])
    |> foreign_key_constraint(:activity_id)
  end
end
