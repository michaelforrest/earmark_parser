# :erlang.system_flag( :schedulers_online, 1)

# ExUnit.configure(exclude: [:wip, :later, :dev, :performance], timeout: 10_000_000)
ExUnit.configure(exclude: [:wip, :later, :dev, :performance])
ExUnit.start(timeout: 5_000)

# SPDX-License-Identifier: Apache-2.0
