defmodule ElixirAgentBenchmark.PlaylistIsolationTest do
  use LiveBeatsWeb.ConnCase

  import Phoenix.LiveViewTest
  import LiveBeats.AccountsFixtures
  import LiveBeats.MediaLibraryFixtures
  alias LiveBeats.MediaLibrary

  setup %{conn: conn} do
    owner = user_fixture(%{username: "bench_playlist_owner"})
    other = user_fixture(%{username: "bench_playlist_other"})
    empty = user_fixture(%{username: "bench_playlist_empty"})

    own_a = song_fixture(%{user_id: owner.id, title: "Owner amber", position: 0})
    own_b = song_fixture(%{user_id: owner.id, title: "Owner birch", position: 1})
    other_a = song_fixture(%{user_id: other.id, title: "Other cedar", position: 0})
    other_b = song_fixture(%{user_id: other.id, title: "Other dahlia", position: 1})

    %{
      conn: log_in_user(conn, owner),
      owner: owner,
      other: other,
      empty: empty,
      own_a: own_a,
      own_b: own_b,
      other_a: other_a,
      other_b: other_b
    }
  end

  test "profile filtering precedes order and limit, including empty profiles", ctx do
    profile = MediaLibrary.get_profile!(ctx.owner)
    assert Enum.map(MediaLibrary.list_profile_songs(profile), & &1.id) == [ctx.own_a.id, ctx.own_b.id]
    assert Enum.map(MediaLibrary.list_profile_songs(profile, 1), & &1.id) == [ctx.own_a.id]
    assert MediaLibrary.list_profile_songs(MediaLibrary.get_profile!(ctx.empty)) == []
  end

  test "the connected profile renders only the selected owner's songs", ctx do
    {:ok, view, html} = live(ctx.conn, "/#{ctx.owner.username}")
    assert html =~ "Owner amber"
    refute html =~ "Other cedar"
    assert has_element?(view, "#songs-#{ctx.own_b.id}")
    refute has_element?(view, "#songs-#{ctx.other_b.id}")
  end

  test "a forged reorder of another user's song cannot mutate either playlist", ctx do
    {:ok, view, _html} = live(ctx.conn, "/#{ctx.owner.username}")

    render_hook(view, "row_dropped", %{
      "id" => "songs-#{ctx.other_a.id}",
      "old" => 0,
      "new" => 1
    })

    assert MediaLibrary.get_song!(ctx.other_a.id).position == 0
    assert MediaLibrary.get_song!(ctx.other_b.id).position == 1
    assert MediaLibrary.get_song!(ctx.own_a.id).position == 0
    assert MediaLibrary.get_song!(ctx.own_b.id).position == 1
    assert render(view) =~ "Owner amber"
  end

  test "owner reorders work and stale old positions are rejected", ctx do
    {:ok, view, _html} = live(ctx.conn, "/#{ctx.owner.username}")

    render_hook(view, "row_dropped", %{
      "id" => "songs-#{ctx.own_a.id}",
      "old" => 0,
      "new" => 1
    })

    assert MediaLibrary.get_song!(ctx.own_a.id).position == 1
    assert MediaLibrary.get_song!(ctx.own_b.id).position == 0

    render_hook(view, "row_dropped", %{
      "id" => "songs-#{ctx.own_a.id}",
      "old" => 0,
      "new" => 0
    })

    assert MediaLibrary.get_song!(ctx.own_a.id).position == 1
    assert MediaLibrary.get_song!(ctx.own_b.id).position == 0
    assert MediaLibrary.get_song!(ctx.other_a.id).position == 0
    assert render(view) =~ "Owner amber"
  end
end
