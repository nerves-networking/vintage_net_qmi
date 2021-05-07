# VintageNetQMI

VintageNet technology support for QMI mobile connections.

```elixir
 VintageNet.configure(
    "wwan0",
    %{
      type: VintageNetQMI,
      vintage_net_qmi: %{
        service_providers: [%{apn: "fill_in"}]
      }
    }
  )
```

