defmodule AccountBalanceTest do
  use ExUnit.Case
  alias Projectors.AccountBalance

  test "account balance projection" do
    {:ok, _} = Registry.start_link(keys: :unique, name: Registry.AccountProjectors)

    AccountBalance.apply_event(%{
      event_type: :amount_deposited,
      value: 12,
      account_number: "NEWACCOUNT"
    })

    AccountBalance.apply_event(%{
      event_type: :amount_deposited,
      value: 30,
      account_number: "NEWACCOUNT"
    })

    assert {:ok, 42} = AccountBalance.lookup_balance("NEWACCOUNT")
    assert {:error, :unknown_account} = AccountBalance.lookup_balance("UNKNOWNACCOUNT")
  end
end
