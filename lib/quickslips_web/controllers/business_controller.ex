defmodule QuickSlipsWeb.BusinessController do
  @moduledoc """
  Saves the seller details typed on a bill's page, without leaving the bill: `POST /api/businesses` with the
  `name`, `address` and `gstin` (the registration number of the country) and the `country` the bill is for. A
  logged-in user only.

  A name the user already has updates that business; a new name makes one. With an `id` (even an empty one) the page
  is explicit: a number updates that business, none makes a new one and a name that is saved is `name_taken`. The answer is the business and what
  happened (`%{business: %{...}, outcome: "created" | "updated"}`), or `%{code: "name_blank"}` /
  `%{code: "tax_id_invalid", label: "NIF"}` with status 422.
  """
  use QuickSlipsWeb, :controller

  alias QuickSlips.Businesses
  alias QuickSlips.Regions
  alias QuickSlipsWeb.UploadController

  action_fallback QuickSlipsWeb.FallbackController

  @doc "How the page (`assets/js/bill`) sees a saved business."
  def payload(business) do
    %{
      id: business.id,
      name: business.name,
      address: business.address,
      gstin: business.gstin,
      logo_url: UploadController.path(business.logo_path),
      signature_id: business.signature_id
    }
  end

  def create(conn, params) do
    with {:ok, scope} <- fetch_scope(conn) do
      {pattern, label} = tax_id(params["country"])

      case Businesses.save_details(scope, params, tax_id: {pattern, label}) do
        {:ok, business, outcome} ->
          json(conn, %{business: payload(business), outcome: outcome})

        {:error, reason} when reason in [:name_taken, :not_found] ->
          conn |> put_status(:unprocessable_entity) |> json(%{code: Atom.to_string(reason)})

        {:error, %Ecto.Changeset{errors: errors}} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(Map.put(refusal(errors), :label, label))
      end
    end
  end

  defp fetch_scope(conn) do
    case conn.assigns[:current_scope] do
      %{user: %{}} = scope -> {:ok, scope}
      _anonymous -> {:error, :unauthorized}
    end
  end

  # The registration number of the country the bill is for: its shape and its name ("GSTIN", "NIF"). A country
  # that has no shape to check lets any number through.
  defp tax_id(country) do
    case Regions.build(country) do
      {:ok, region} ->
        id = get_in(region, ["tax", "id"]) || %{}
        {id["pattern"] && Regex.compile!(id["pattern"]), id["label"] || "registration number"}

      {:error, _reason} ->
        {nil, "registration number"}
    end
  end

  defp refusal(errors) do
    if Keyword.has_key?(errors, :name), do: %{code: "name_blank"}, else: %{code: "tax_id_invalid"}
  end
end
