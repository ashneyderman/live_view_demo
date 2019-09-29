defmodule LiveViewDemoWeb.TetrisLive do
  use Phoenix.LiveView

  @height 26
  @width 26
  @field_delta_y 40
  @default_level 3
  @default_height 22

  alias Tetris.Shape

  def render(%{game_state: :over} = assigns) do
    ~L"""
    <div class="tetris-container">
      <div class="game-over">
        <h1>GAME OVER <small>SCORE: <%= @score %></h1>
        <button phx-click="new_game">NEW GAME</button>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~L"""
    <div class="tetris-controls">

    </div>
    <div class="tetris-container" phx-keydown="keydown" phx-target="window">
      <h3 class="score" style="font-size: 14px;">SCORE:&nbsp;<%= @score %></h3>
      <%= for block <- @field_blocks do %>
        <div class="block field"
            style="left: <%= block.x %>px;
                   top: <%= block.y %>px;
                   width: <%= @width %>px;
                   height: <%= @height %>px;
        "></div>
      <% end %>
      <%= for block <- @shape_blocks do %>
        <div class="block shape"
            style="left: <%= block.x %>px;
                   top: <%= block.y %>px;
                   width: <%= @width %>px;
                   height: <%= @height %>px;
        "></div>
      <% end %>
      <%= for block <- @jar_blocks do %>
        <div class="block jar"
            style="left: <%= block.x %>px;
                   top: <%= block.y %>px;
                   width: <%= block.width %>px;
                   height: <%= block.height %>px;
        "></div>
      <% end %>
    </div>
    """
  end

  def mount(_session, socket) do
    new_socket = start_new_game(socket)
    {:ok, new_socket}
  end

  def handle_info(
        {:state_change,
         %{
           field: field,
           current_shape: shape,
           current_shape_coord: [x, y],
           score: score,
           game_state: game_state
         }},
        socket
      ) do
    shape_blocks = build_shape_blocks(shape, x, y, 0, @field_delta_y)
    field_blocks = build_field_blocks(field, 0, @field_delta_y)
    jar_blocks = build_jar_blocks(field.width, field.height, 0, @field_delta_y)

    new_socket =
      socket
      |> assign(:game_state, game_state)
      |> assign(:shape_blocks, shape_blocks)
      |> assign(:field_blocks, field_blocks)
      |> assign(:jar_blocks, jar_blocks)
      |> assign(:score, score)
      |> assign(:width, @width)
      |> assign(:height, @height)

    {:noreply, new_socket}
  end

  def handle_event("keydown", "ArrowRight", socket) do
    gc = socket.assigns.game_controller
    Process.send(gc, {:key_press, :right}, [])
    {:noreply, socket}
  end

  def handle_event("keydown", "ArrowLeft", socket) do
    gc = socket.assigns.game_controller
    Process.send(gc, {:key_press, :left}, [])
    {:noreply, socket}
  end

  def handle_event("keydown", "ArrowUp", socket) do
    gc = socket.assigns.game_controller
    Process.send(gc, {:key_press, :rotate_ccw}, [])
    {:noreply, socket}
  end

  def handle_event("keydown", "ArrowDown", socket) do
    gc = socket.assigns.game_controller
    Process.send(gc, {:key_press, :rotate_cw}, [])
    {:noreply, socket}
  end

  def handle_event("keydown", "Escape", socket) do
    gc = socket.assigns.game_controller
    Process.send(gc, {:key_press, :toggle_state}, [])
    {:noreply, socket}
  end

  def handle_event("new_game", "", socket) do
    {:noreply, start_new_game(socket)}
  end

  def handle_event(_event, _msg, socket) do
    {:noreply, socket}
  end

  defp build_jar_blocks(width, height, delta_x, delta_y) do
    b0 = for row <- 0..(height - 1) do
      %{
        x: -1,
        y: row * @height + delta_y,
        height: @height,
        width: 1
      }
    end
    b1 = for row <- 0..(height - 1) do
      %{
        x: width * @width + 1,
        y: row * @height + delta_y,
        height: @height,
        width: 1
      }
    end

    b2 = for col <- 0..(width - 1) do
      %{
        x: col * @width,
        y: height * @height + delta_y,
        height: 2,
        width: @width
      }
    end

    b0 ++ b1 ++ b2
  end

  defp build_field_blocks(field, delta_x, delta_y) do
    for {row, row_number} <- Enum.with_index(field.cells),
        {col, col_number} <- Enum.with_index(row) do
      if col == 1 do
        %{
          x: col_number * @width + delta_x,
          y: row_number * @height + delta_y
        }
      else
        nil
      end
    end
    |> Enum.filter(&(&1 != nil))
  end

  defp build_shape_blocks(shape, x, y, delta_x, delta_y) do
    shape
    |> Shape.shift(x, y, snap_to_field: true)
    |> (fn %Shape{coords: coords} -> coords end).()
    |> Enum.map(fn [col, row] ->
      if col >= 0 && row >= 0 do
        %{
          x: col * @width + delta_x,
          y: row * @height + delta_y
        }
      else
        nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp start_new_game(socket) do
    {:ok, gc} =
      DynamicSupervisor.start_child(
        Tetris.GameControllerSup,
        %{
          id: Tetris.GameController,
          start:
            {Tetris.GameController, :start_link,
             [[state_change_listener: self(), level: @default_level, height: @default_height]]},
          restart: :temporary
        }
      )

    socket
    |> assign(:game_controller, gc)
    |> assign(:score, 0)
    |> assign(:shape_blocks, [])
    |> assign(:field_blocks, [])
    |> assign(:jar_blocks, [])
    |> assign(:width, @width)
    |> assign(:height, @height)
  end
end
