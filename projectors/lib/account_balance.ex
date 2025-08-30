defmodule Projectors.AccountBalance do
  use GenServer
  require Logger

  def start_link(account_number) do
    GenServer.start_link(
      __MODULE__,
      account_number,
      name: via(account_number)
    )
  end

  @impl true
  def init(account_number) do
    {:ok, %{balance: 0, account_number: account_number}}
  end

  defp via(account_number) do
    {:via, Registry, {Registry.AccountProjectors, account_number}}
  end

  def apply_event(%{account_number: account} = event) when is_binary(account) do
    case Registry.lookup(Registry.AccountProjectors, account) do
      [{pid, _}] ->
        apply_event(pid, event)

      _ ->
        Logger.debug("Attempt to apply event to non-existent account, starting projector")
        {:ok, pid} = start_link(account)
        apply_event(pid, event)
    end
  end

  defp apply_event(pid, event) when is_pid(pid) do
    GenServer.cast(pid, {:handle_event, event})
  end

  @impl true
  def handle_cast({:handle_event, event}, state) do
    {:noreply, handle_event(state, event)}
  end

  def handle_event(%{balance: balance} = state, %{event_type: :amount_withdrawn, value: value}) do
    %{state | balance: balance - value}
  end

  def handle_event(%{balance: balance} = state, %{event_type: :amount_deposited, value: value}) do
    %{state | balance: balance + value}
  end

  def handle_event(%{balance: balance} = state, %{event_type: :fee_applied, value: value}) do
    %{state | balance: balance - value}
  end

  def lookup_balance(account_number) when is_binary(account_number) do
    with [{pid, _}] <- Registry.lookup(Registry.AccountProjectors, account_number) do
      {:ok, get_balance(pid)}
    else
      _ -> {:error, :unknown_account}
    end
  end

  def get_balance(pid) do
    GenServer.call(pid, :get_balance)
  end

  @impl true
  def handle_call(:get_balance, _from, %{balance: balance} = state) do
    {:reply, balance, state}
  end
end
