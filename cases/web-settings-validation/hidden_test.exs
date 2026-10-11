defmodule ElixirAgentBenchmark.SettingsValidationTest do
  use LiveBeatsWeb.ConnCase

  import Phoenix.LiveViewTest
  import LiveBeats.AccountsFixtures
  alias LiveBeats.Accounts

  setup %{conn: conn} do
    user = user_fixture(%{username: "bench_settings_owner"})
    other = user_fixture(%{username: "bench_settings_other"})
    {:ok, user} = Accounts.update_public_settings(user, %{profile_tagline: "Original beats"})
    %{conn: log_in_user(conn, user), user: user, other: other}
  end

  test "the context rejects an empty tagline and preserves persisted settings", %{user: user} do
    assert {:error, changeset} =
             Accounts.update_public_settings(user, %{
               "username" => user.username,
               "profile_tagline" => ""
             })

    assert Keyword.has_key?(changeset.errors, :profile_tagline)
    stored = Accounts.get_user!(user.id)
    assert stored.username == user.username
    assert stored.profile_tagline == "Original beats"
  end

  test "validation exposes field errors without writing to the database", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, "/profile/settings")

    html =
      view
      |> form("#settings-form", user: %{username: user.username, profile_tagline: ""})
      |> render_change()

    assert html =~ "blank"
    assert Accounts.get_user!(user.id).profile_tagline == "Original beats"
  end

  test "invalid submission can be corrected and saved in the same session", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, "/profile/settings")

    html =
      view
      |> form("#settings-form", user: %{username: user.username, profile_tagline: ""})
      |> render_submit()

    assert html =~ "blank"
    assert Accounts.get_user!(user.id).profile_tagline == "Original beats"

    view
    |> form("#settings-form", user: %{username: user.username, profile_tagline: "Restored rhythm"})
    |> render_submit()

    assert Accounts.get_user!(user.id).profile_tagline == "Restored rhythm"
  end

  test "a taken username still fails while valid edits still succeed", %{user: user, other: other} do
    assert {:error, _changeset} =
             Accounts.update_public_settings(user, %{
               username: other.username,
               profile_tagline: "Must not be persisted"
             })

    assert Accounts.get_user!(user.id).username == user.username

    assert {:ok, updated} =
             Accounts.update_public_settings(user, %{
               username: "bench_settings_renamed",
               profile_tagline: "New name, same collection"
             })

    assert updated.username == "bench_settings_renamed"
    assert Accounts.get_user!(user.id).profile_tagline == "New name, same collection"
  end
end
