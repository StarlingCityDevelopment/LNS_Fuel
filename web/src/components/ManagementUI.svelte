<script>
  let { station = $bindable(), config, closeUI, t } = $props();

  let activeTab = $state("dashboard");
  let renameInput = $state("");
  /** @type {any} */
  let withdrawAmount = $state("");
  /** @type {any} */
  let depositAmount = $state("");
  let priceValue = $state(5);
  /** @type {any} */
  let hireServerId = $state("");

  $effect(() => {
    if (station) {
      renameInput = station.name ?? "";
      priceValue = station.price ?? 5;
    }
  });

  let fuelPercentage = $derived(
    station ? Math.floor((station.stock / station.capacity) * 100) : 0,
  );

  let calculatedRefund = $derived.by(() => {
    if (!station || !config) return 0;
    const baseRefund = config.upgrades ? 75000 * 0.6 : 0;
    let upgradeRefund = 0;

    if (config.upgrades && station.upgrades) {
      for (const [upgradeType, level] of Object.entries(station.upgrades)) {
        const upgradeConf = config.upgrades[upgradeType];
        if (upgradeConf) {
          for (let lvl = 1; lvl <= level; lvl++) {
            const lvlData = upgradeConf.levels[lvl - 1];
            if (lvlData) {
              upgradeRefund += lvlData.price * 0.5;
            }
          }
        }
      }
    }
    return Math.floor(baseRefund + upgradeRefund);
  });

  function rename() {
    if (renameInput.trim().length < 3 || renameInput.trim().length > 30) return;
    fetch(`https://LNS_Fuel/renameStation`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ stationId: station.id, name: renameInput.trim() }),
    });
  }

  function withdraw() {
    const val = parseInt(withdrawAmount);
    if (isNaN(val) || val <= 0 || val > station.balance) return;
    fetch(`https://LNS_Fuel/withdrawMoney`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ stationId: station.id, amount: val }),
    });
    withdrawAmount = "";
  }

  function deposit() {
    const val = parseInt(depositAmount);
    if (isNaN(val) || val <= 0) return;
    fetch(`https://LNS_Fuel/depositMoney`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ stationId: station.id, amount: val }),
    });
    depositAmount = "";
  }

  function updatePrice() {
    fetch(`https://LNS_Fuel/setPrice`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ stationId: station.id, price: priceValue }),
    });
  }

  let timeLeft = $state(0);

  function formatTime(seconds) {
    if (seconds <= 0) return "00:00";
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  }

  $effect(() => {
    if (
      station?.activeDelivery &&
      station.activeDelivery.isAuto &&
      station.activeDelivery.endTime
    ) {
      const now = Math.floor(Date.now() / 1000);
      timeLeft = Math.max(0, station.activeDelivery.endTime - now);

      const interval = setInterval(() => {
        const currentNow = Math.floor(Date.now() / 1000);
        const diff = station.activeDelivery.endTime - currentNow;
        timeLeft = Math.max(0, diff);
        if (diff <= 0) {
          clearInterval(interval);
        }
      }, 1000);

      return () => clearInterval(interval);
    } else {
      timeLeft = 0;
    }
  });

  let elapsedPercentage = $derived.by(() => {
    if (
      !station?.activeDelivery?.endTime ||
      !station?.activeDelivery?.startTime
    )
      return 0;
    const total =
      station.activeDelivery.endTime - station.activeDelivery.startTime;
    if (total <= 0) return 100;
    const elapsed = total - timeLeft;
    return Math.min(100, Math.max(0, (elapsed / total) * 100));
  });

  /** @param {number} index
   * @param {boolean} isAuto */
  function orderStock(index, isAuto = false) {
    fetch(`https://LNS_Fuel/orderStock`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ stationId: station.id, index: index + 1, isAuto }),
    });
  }

  /** @param {string} upgradeType */
  function buyUpgrade(upgradeType) {
    fetch(`https://LNS_Fuel/buyUpgrade`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ stationId: station.id, upgradeType }),
    });
  }

  function sellStation() {
    closeUI();
    fetch(`https://LNS_Fuel/sellStation`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ stationId: station.id }),
    });
  }

  function hireEmployee() {
    const val = parseInt(hireServerId);
    if (isNaN(val) || val <= 0) return;
    fetch(`https://LNS_Fuel/hireEmployee`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ stationId: station.id, serverId: val }),
    });
    hireServerId = "";
  }

  /** @param {string} identifier */
  function fireEmployee(identifier) {
    fetch(`https://LNS_Fuel/fireEmployee`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ stationId: station.id, identifier }),
    });
  }

  function getShippingDiscountPercent() {
    if (!station || !config) return "0%";
    const level = station.upgrades.shippingDiscount || 0;
    if (level === 0) return "0%";
    const conf = config.upgrades.shippingDiscount.levels[level - 1];
    return conf ? `${Math.floor(conf.value * 100)}%` : "0%";
  }
</script>

<div class="management-card">
  <header class="top-navbar">
    <div class="brand-section">
      <div class="brand-icon">
        <i class="fa-solid fa-gas-pump"></i>
      </div>
      <div class="brand-details">
        <h2>{t("mgt_brand_title", "Fuel Logistics")}</h2>
      </div>
    </div>

    <nav class="nav-menu">
      <button
        class="nav-item"
        class:active={activeTab === "dashboard"}
        onclick={() => (activeTab = "dashboard")}
      >
        {t("tab_dashboard", "Dashboard")}
      </button>
      {#if station.role === "owner"}
        <button
          class="nav-item"
          class:active={activeTab === "finances"}
          onclick={() => (activeTab = "finances")}
        >
          {t("tab_finances", "Finances")}
        </button>
      {/if}
      <button
        class="nav-item"
        class:active={activeTab === "stock"}
        onclick={() => (activeTab = "stock")}
      >
        {t("tab_pumps_stock", "Pumps & Stock")}
      </button>
      {#if station.role === "owner"}
        <button
          class="nav-item"
          class:active={activeTab === "employees"}
          onclick={() => (activeTab = "employees")}
        >
          {t("tab_employees", "Employees")}
        </button>
        <button
          class="nav-item"
          class:active={activeTab === "upgrades"}
          onclick={() => (activeTab = "upgrades")}
        >
          {t("tab_upgrades", "Upgrades")}
        </button>
        <button
          class="nav-item"
          class:active={activeTab === "sell"}
          onclick={() => (activeTab = "sell")}
        >
          {t("tab_sell", "Sell Venture")}
        </button>
      {/if}
    </nav>

    <div class="navbar-right">
      <button class="close-btn" onclick={closeUI}>
        <i class="fa-solid fa-right-from-bracket" style="margin-right: 6px;"
        ></i>
        {t("btn_close_terminal", "Close Terminal")}
      </button>
    </div>
  </header>

  <main class="main-content">
    <header class="content-header">
      <div class="title-area">
        <h1>{station.name}</h1>
        <p>{t("mgt_sub_title", "Station Operator Terminal")}</p>
      </div>
      <span class="station-badge">ID: {station.prettyId || station.id}</span>
    </header>

    {#if activeTab === "dashboard"}
      <div class="tab-content">
        <div class="stats-grid">
          <div class="stat-card">
            <span class="stat-label"
              >{t("mgt_capital_balance", "Capital Balance")}</span
            >
            <span class="stat-value">${station.balance.toLocaleString()}</span>
            <span class="stat-desc"
              >{t(
                "mgt_capital_balance_desc",
                "Available for stock & upgrades",
              )}</span
            >
          </div>
          <div class="stat-card success">
            <span class="stat-label">{t("mgt_fuel_stock", "Fuel Stock")}</span>
            <span class="stat-value">{station.stock.toLocaleString()}L</span>
            <span class="stat-desc"
              >{t(
                "mgt_capacity",
                "Capacity: %sL",
                station.capacity.toLocaleString(),
              )}</span
            >
          </div>
          <div class="stat-card warning">
            <span class="stat-label"
              >{t("mgt_fuel_retail_price", "Fuel Retail Price")}</span
            >
            <span class="stat-value">${station.price}/L</span>
            <span class="stat-desc"
              >{t("mgt_market_average", "Market average: $5")}</span
            >
          </div>
        </div>

        <div
          class="dashboard-row"
          style={station.role !== "owner" ? "grid-template-columns: 1fr;" : ""}
        >
          <div class="panel-card">
            <h3 class="panel-title">
              <i class="fa-solid fa-chart-column"></i>
              {t("mgt_operational_summary", "Operational Summary")}
            </h3>
            <div class="stock-visualizer">
              <div class="fuel-gauge-container">
                <svg class="fuel-gauge-svg" width="140" height="140">
                  <circle class="fuel-gauge-bg" cx="70" cy="70" r="58" />
                  <circle
                    class="fuel-gauge-fill"
                    cx="70"
                    cy="70"
                    r="58"
                    stroke-dasharray="364.4"
                    stroke-dashoffset={364.4 * (1 - fuelPercentage / 100)}
                  />
                </svg>
                <div class="fuel-gauge-text">
                  <span class="fuel-percentage">{fuelPercentage}%</span>
                  <p class="fuel-label">{t("mgt_fuel_left", "FUEL LEFT")}</p>
                </div>
              </div>
              <div class="stock-stats">
                <div class="stock-row">
                  <span>{t("mgt_total_sales", "Total Sales")}</span>
                  <span
                    >{t(
                      "mgt_liters",
                      "%s Liters",
                      (station.statistics?.totalSales || 0).toLocaleString(),
                    )}</span
                  >
                </div>
                <div class="stock-row">
                  <span>{t("mgt_lifetime_revenue", "Lifetime Revenue")}</span>
                  <span
                    >${(
                      station.statistics?.totalRevenue || 0
                    ).toLocaleString()}</span
                  >
                </div>
                <div class="stock-row">
                  <span>{t("mgt_served_clients", "Served Clients")}</span>
                  <span
                    >{t(
                      "mgt_customers",
                      "%s customers",
                      (
                        station.statistics?.lifetimeClients || 0
                      ).toLocaleString(),
                    )}</span
                  >
                </div>
              </div>
            </div>
          </div>

          {#if station.role === "owner"}
            <div class="panel-card">
              <h3 class="panel-title">
                {t("mgt_rename_venture", "Rename Venture")}
              </h3>
              <p style="font-size: 0.85rem; color: var(--text-muted);">
                {t(
                  "mgt_rename_desc",
                  "Name must be 3-30 letters and not contain restricted words.",
                )}
              </p>
              <div class="rename-form">
                <input
                  type="text"
                  class="input-field"
                  placeholder={t(
                    "mgt_rename_placeholder",
                    "Enter station name...",
                  )}
                  bind:value={renameInput}
                />
                <button
                  class="primary-btn"
                  onclick={rename}
                  disabled={renameInput.trim().length < 3 ||
                    renameInput.trim().length > 30}
                >
                  {t("btn_save", "Save")}
                </button>
              </div>
            </div>
          {/if}
        </div>
      </div>
    {/if}

    {#if activeTab === "finances"}
      <div class="tab-content">
        <div class="stats-grid">
          <div class="stat-card">
            <span class="stat-label"
              >{t("mgt_current_balance", "Current Balance")}</span
            >
            <span class="stat-value">${station.balance.toLocaleString()}</span>
            <span class="stat-desc"
              >{t(
                "mgt_current_balance_desc",
                "Deducted when shipments are ordered",
              )}</span
            >
          </div>
        </div>

        <div class="upgrades-grid">
          <div class="panel-card">
            <h3 class="panel-title">
              {t("mgt_withdraw_title", "Withdraw Vault Funds")}
            </h3>
            <p style="font-size: 0.85rem; color: var(--text-muted);">
              {t(
                "mgt_withdraw_desc",
                "Transfer station revenues directly into your player character's wallet.",
              )}
            </p>
            <div class="rename-form" style="margin-top: 10px;">
              <input
                type="number"
                class="input-field"
                placeholder={t(
                  "mgt_withdraw_placeholder",
                  "Amount to withdraw...",
                )}
                bind:value={withdrawAmount}
                min="1"
                max={station.balance}
              />
              <button
                class="primary-btn"
                onclick={withdraw}
                disabled={!withdrawAmount ||
                  withdrawAmount <= 0 ||
                  withdrawAmount > station.balance}
              >
                {t("btn_withdraw", "Withdraw")}
              </button>
            </div>
          </div>

          <div class="panel-card">
            <h3 class="panel-title">
              {t("mgt_deposit_title", "Deposit Capital")}
            </h3>
            <p style="font-size: 0.85rem; color: var(--text-muted);">
              {t(
                "mgt_deposit_desc",
                "Inject personal cash into the business accounts to purchase refills or upgrades.",
              )}
            </p>
            <div class="rename-form" style="margin-top: 10px;">
              <input
                type="number"
                class="input-field"
                placeholder={t(
                  "mgt_deposit_placeholder",
                  "Amount to deposit...",
                )}
                bind:value={depositAmount}
                min="1"
              />
              <button
                class="primary-btn"
                onclick={deposit}
                disabled={!depositAmount || depositAmount <= 0}
              >
                {t("btn_deposit", "Deposit")}
              </button>
            </div>
          </div>
        </div>
      </div>
    {/if}

    {#if activeTab === "stock"}
      <div class="tab-content">
        {#if station.activeDelivery}
          {@const delivery = station.activeDelivery}
          <div
            class="active-delivery-card"
            class:auto-delivery={delivery.isAuto}
          >
            <div class="delivery-header">
              <div class="delivery-title">
                <i class="fa-solid fa-truck-ramp-box"></i>
                {#if delivery.isAuto}
                  <h3>
                    {t("mgt_delivery_auto_title", "Automated Cargo Shipment")}
                  </h3>
                {:else}
                  <h3>
                    {t(
                      "mgt_delivery_manual_title",
                      "Self-Drive Cargo Shipment",
                    )}
                  </h3>
                {/if}
              </div>
              {#if delivery.isAuto}
                <span class="time-countdown">{formatTime(timeLeft)}</span>
              {:else}
                <span class="manual-badge"
                  >{t("mgt_delivery_manual_badge", "In Progress")}</span
                >
              {/if}
            </div>

            <div class="delivery-details-brief">
              <span class="delivery-amount">
                {t(
                  "mgt_delivery_amount_desc",
                  "Transporting %sL of fuel",
                  delivery.amount.toLocaleString(),
                )}
              </span>
              <span class="delivery-type-label">
                {t(delivery.label, delivery.label)}
              </span>
            </div>

            {#if delivery.isAuto}
              <div class="delivery-progress-container">
                <div class="progress-bar-wrapper">
                  <div
                    class="progress-bar-fill"
                    style="width: {elapsedPercentage}%"
                  ></div>
                </div>
                <div class="progress-footer">
                  <span
                    >{t(
                      "mgt_delivery_progress_status",
                      "Hired driver is retrieving shipment...",
                    )}</span
                  >
                  <span>{Math.floor(elapsedPercentage)}%</span>
                </div>
              </div>
            {:else}
              <div class="delivery-manual-instruction">
                <i class="fa-solid fa-location-dot"></i>
                <p>
                  {t(
                    "mgt_delivery_manual_instruction",
                    "Retrieve the delivery truck from the depot and drive it back to your station to unload.",
                  )}
                </p>
              </div>
            {/if}
          </div>
        {/if}

        <div
          class="dashboard-row"
          style={station.role !== "owner" ? "grid-template-columns: 1fr;" : ""}
        >
          {#if station.role === "owner"}
            <div class="panel-card">
              <h3 class="panel-title">
                {t("mgt_pricing_title", "Retail Pricing")}
              </h3>
              <p style="font-size: 0.85rem; color: var(--text-muted);">
                {t(
                  "mgt_pricing_desc",
                  "Adjust the fuel price per liter paid by players. Setting high prices will yield larger profits but may deter clients.",
                )}
              </p>
              <div class="pricing-container">
                <div class="price-display">
                  <span class="price-val">${priceValue}</span>
                  <span style="color: var(--text-muted); font-size: 1.2rem;"
                    >/ L</span
                  >
                </div>
                <div class="slider-wrapper">
                  <input
                    type="range"
                    class="price-slider"
                    min={config.minPrice}
                    max={config.maxPrice}
                    bind:value={priceValue}
                    onchange={updatePrice}
                  />
                  <div class="slider-limits">
                    <span
                      >{t("mgt_pricing_min", "Min: $%s", config.minPrice)}</span
                    >
                    <span
                      >{t("mgt_pricing_max", "Max: $%s", config.maxPrice)}</span
                    >
                  </div>
                </div>
              </div>
            </div>
          {/if}

          <div class="panel-card">
            <h3 class="panel-title">
              {t("mgt_logistics_status", "Logistics Status")}
            </h3>
            <div
              style="display: flex; flex-direction: column; gap: 12px; margin-top: 10px;"
            >
              <div class="stock-row">
                <span>{t("mgt_active_stock", "Active Stock")}</span>
                <span style="color: var(--color-primary);"
                  >{t(
                    "mgt_liters",
                    "%s Liters",
                    station.stock.toLocaleString(),
                  )}</span
                >
              </div>
              <div class="stock-row">
                <span>{t("mgt_storage_limit", "Storage Limit")}</span>
                <span
                  >{t(
                    "mgt_liters",
                    "%s Liters",
                    station.capacity.toLocaleString(),
                  )}</span
                >
              </div>
              <div class="stock-row">
                <span>{t("mgt_import_discount", "Import Discount")}</span>
                <span style="color: var(--color-success);"
                  >{getShippingDiscountPercent()}</span
                >
              </div>
            </div>
          </div>
        </div>

        <div class="panel-card">
          <h3 class="panel-title">
            {t("mgt_orders_title", "Order Fuel Deliveries")}
          </h3>
          <p style="font-size: 0.85rem; color: var(--text-muted);">
            {t(
              "mgt_orders_desc",
              "Deliveries are imported directly. Shipping costs are paid from the business vault balance. Upgrades reduce shipping fees.",
            )}
          </p>
          <div class="stock-orders-list">
            {#each config.stockOrders as order, i}
              {@const hasActiveDelivery = !!station.activeDelivery}
              {@const discount = station.upgrades?.shippingDiscount
                ? config.upgrades?.shippingDiscount.levels[
                    station.upgrades.shippingDiscount - 1
                  ]?.value || 0
                : 0}
              {@const orderCost = Math.floor(order.price * (1 - discount))}
              {@const aiCost = orderCost + (config.aiDispatchFee || 250)}
              {@const hasDriverUpgrade =
                (station.upgrades?.hiredDriver || 0) > 0}
              <div class="stock-order-row">
                <div class="order-details">
                  <h4>{t(order.label, order.label)}</h4>
                  <p>
                    {t(
                      "mgt_orders_row_desc",
                      "Refill %s liters of fuel",
                      order.amount.toLocaleString(),
                    )}
                  </p>
                </div>
                <div class="order-actions">
                  <div class="order-prices">
                    <span class="order-price"
                      >${orderCost.toLocaleString()}</span
                    >
                    {#if config.upgrades?.hiredDriver?.enabled}
                      <span
                        class="order-ai-price"
                        title="Includes hired driver surcharge"
                      >
                        ${aiCost.toLocaleString()}
                        {t("mgt_with_driver", "w/ Driver")}
                      </span>
                    {/if}
                  </div>
                  <div class="order-buttons-group">
                    <button
                      class="order-btn secondary"
                      onclick={() => orderStock(i, false)}
                      disabled={hasActiveDelivery ||
                        station.stock + order.amount > station.capacity ||
                        station.balance < orderCost}
                    >
                      {config.upgrades?.hiredDriver?.enabled
                        ? t("btn_self_drive", "Self-Drive")
                        : t("btn_import", "Import")}
                    </button>
                    {#if config.upgrades?.hiredDriver?.enabled}
                      <button
                        class="order-btn"
                        onclick={() => orderStock(i, true)}
                        disabled={hasActiveDelivery ||
                          !hasDriverUpgrade ||
                          station.stock + order.amount > station.capacity ||
                          station.balance < aiCost}
                        title={!hasDriverUpgrade
                          ? t(
                              "hint_requires_dispatch_upgrade",
                              "Requires Hired Driver Contract Upgrade",
                            )
                          : ""}
                      >
                        {t("btn_hire_driver", "Hire Driver")}
                      </button>
                    {/if}
                  </div>
                </div>
              </div>
            {/each}
          </div>
        </div>
      </div>
    {/if}

    {#if activeTab === "upgrades"}
      <div class="tab-content">
        <p
          style="font-size: 0.9rem; color: var(--text-muted); margin-bottom: 10px;"
        >
          {t(
            "mgt_upgrades_desc",
            "Unlock station upgrades to store more stock and lower shipping costs.",
          )}
        </p>
        <div class="upgrades-grid">
          {#if config.upgrades?.capacity}
            {@const capLvl = station.upgrades?.capacity || 0}
            {@const maxCapLvl = config.upgrades.capacity.levels?.length || 0}
            {@const nextCapData =
              capLvl < maxCapLvl
                ? config.upgrades.capacity.levels[capLvl]
                : null}
            <div class="upgrade-card">
              <div class="upgrade-info">
                <h3>
                  {t(
                    config.upgrades.capacity.title,
                    config.upgrades.capacity.title,
                  )}
                </h3>
                <p>
                  {t(
                    config.upgrades.capacity.description,
                    config.upgrades.capacity.description,
                  )}
                </p>
                <p style="margin-top: 10px; color: #fff;">
                  {t(
                    "mgt_upgrade_current_cap",
                    "Current: %s",
                    station.capacity.toLocaleString() + "L",
                  )}
                  {#if nextCapData}
                    {" "}{t(
                      "mgt_upgrade_next_cap",
                      "➔ Next: %s",
                      nextCapData.value.toLocaleString() + "L",
                    )}
                  {/if}
                </p>
                <div class="upgrade-level-indicator">
                  {#each Array(maxCapLvl) as _, i}
                    <div class="level-dot" class:active={i < capLvl}></div>
                  {/each}
                </div>
              </div>
              <div class="upgrade-action">
                {#if nextCapData}
                  <span class="upgrade-cost"
                    >${nextCapData.price.toLocaleString()}</span
                  >
                  <button
                    class="upgrade-btn"
                    onclick={() => buyUpgrade("capacity")}
                    disabled={station.balance < nextCapData.price}
                  >
                    {t("btn_upgrade", "Upgrade")}
                  </button>
                {:else}
                  <span
                    class="upgrade-cost"
                    style="color: var(--color-success);"
                    >{t("mgt_max_level", "MAX LEVEL")}</span
                  >
                  <button class="upgrade-btn maxed" disabled
                    >{t("btn_completed", "Completed")}</button
                  >
                {/if}
              </div>
            </div>
          {/if}

          {#if config.upgrades?.shippingDiscount}
            {@const discLvl = station.upgrades?.shippingDiscount || 0}
            {@const maxDiscLvl =
              config.upgrades.shippingDiscount.levels?.length || 0}
            {@const nextDiscData =
              discLvl < maxDiscLvl
                ? config.upgrades.shippingDiscount.levels[discLvl]
                : null}
            <div class="upgrade-card">
              <div class="upgrade-info">
                <h3>
                  {t(
                    config.upgrades.shippingDiscount.title,
                    config.upgrades.shippingDiscount.title,
                  )}
                </h3>
                <p>
                  {t(
                    config.upgrades.shippingDiscount.description,
                    config.upgrades.shippingDiscount.description,
                  )}
                </p>
                <p style="margin-top: 10px; color: #fff;">
                  {t(
                    "mgt_upgrade_current_cap",
                    "Current: %s",
                    discLvl > 0
                      ? `${Math.floor(config.upgrades.shippingDiscount.levels[discLvl - 1].value * 100)}%`
                      : "0%",
                  )}
                  {#if nextDiscData}
                    {" "}{t(
                      "mgt_upgrade_next_disc",
                      "➔ Next: %s% discount",
                      Math.floor(nextDiscData.value * 100),
                    )}
                  {/if}
                </p>
                <div class="upgrade-level-indicator">
                  {#each Array(maxDiscLvl) as _, i}
                    <div class="level-dot" class:active={i < discLvl}></div>
                  {/each}
                </div>
              </div>
              <div class="upgrade-action">
                {#if nextDiscData}
                  <span class="upgrade-cost"
                    >${nextDiscData.price.toLocaleString()}</span
                  >
                  <button
                    class="upgrade-btn"
                    onclick={() => buyUpgrade("shippingDiscount")}
                    disabled={station.balance < nextDiscData.price}
                  >
                    {t("btn_upgrade", "Upgrade")}
                  </button>
                {:else}
                  <span
                    class="upgrade-cost"
                    style="color: var(--color-success);"
                    >{t("mgt_max_level", "MAX LEVEL")}</span
                  >
                  <button class="upgrade-btn maxed" disabled
                    >{t("btn_completed", "Completed")}</button
                  >
                {/if}
              </div>
            </div>
          {/if}

          {#if config.upgrades?.hiredDriver && config.upgrades.hiredDriver.enabled}
            {@const hdLvl = station.upgrades?.hiredDriver || 0}
            {@const maxHdLvl = config.upgrades.hiredDriver.levels?.length || 0}
            {@const nextHdData =
              hdLvl < maxHdLvl
                ? config.upgrades.hiredDriver.levels[hdLvl]
                : null}
            <div class="upgrade-card">
              <div class="upgrade-info">
                <h3>
                  {t(
                    config.upgrades.hiredDriver.title,
                    config.upgrades.hiredDriver.title,
                  )}
                </h3>
                <p>
                  {t(
                    config.upgrades.hiredDriver.description,
                    config.upgrades.hiredDriver.description,
                  )}
                </p>
                <p style="margin-top: 10px; color: #fff;">
                  {t(
                    "mgt_upgrade_current_driver",
                    "Current: %s",
                    hdLvl > 0
                      ? t(`mgt_driver_lvl_${hdLvl}`, `Level ${hdLvl} Driver`)
                      : t("mgt_driver_none", "None"),
                  )}
                  {#if nextHdData}
                    {" "}{t(
                      "mgt_upgrade_next_driver",
                      "➔ Next: Level %s (Delivery: %s mins)",
                      nextHdData.level,
                      Math.floor(nextHdData.value / 60),
                    )}
                  {/if}
                </p>
                <div class="upgrade-level-indicator">
                  {#each Array(maxHdLvl) as _, i}
                    <div class="level-dot" class:active={i < hdLvl}></div>
                  {/each}
                </div>
              </div>
              <div class="upgrade-action">
                {#if nextHdData}
                  <span class="upgrade-cost"
                    >${nextHdData.price.toLocaleString()}</span
                  >
                  <button
                    class="upgrade-btn"
                    onclick={() => buyUpgrade("hiredDriver")}
                    disabled={station.balance < nextHdData.price}
                  >
                    {t("btn_upgrade", "Upgrade")}
                  </button>
                {:else}
                  <span
                    class="upgrade-cost"
                    style="color: var(--color-success);"
                    >{t("mgt_max_level", "MAX LEVEL")}</span
                  >
                  <button class="upgrade-btn maxed" disabled
                    >{t("btn_completed", "Completed")}</button
                  >
                {/if}
              </div>
            </div>
          {/if}
        </div>
      </div>
    {/if}

    {#if activeTab === "employees" && station.role === "owner"}
      <div class="tab-content">
        <div class="dashboard-row">
          <div class="panel-card">
            <h3 class="panel-title">
              <i class="fa-solid fa-users"></i>
              {t("mgt_employees_title", "Manage Employees")}
            </h3>
            <p style="font-size: 0.85rem; color: var(--text-muted);">
              {t(
                "mgt_employees_desc",
                "Hire other players to help you manage stock and perform fuel delivery runs.",
              )}
            </p>
            <div class="stock-orders-list">
              {#if station.employees && station.employees.length > 0}
                {#each station.employees as emp}
                  <div class="stock-order-row">
                    <div class="order-details">
                      <h4>{emp.name}</h4>
                      <p>
                        {t(
                          "mgt_employee_role",
                          "Role: %s",
                          t("mgt_role_employee", "Employee"),
                        )} • ID: {emp.identifier}
                      </p>
                    </div>
                    <div class="order-actions">
                      <button
                        class="primary-btn"
                        style="background: var(--color-danger, #ef4444); color: #fff;"
                        onclick={() => fireEmployee(emp.identifier)}
                      >
                        {t("btn_fire", "Fire")}
                      </button>
                    </div>
                  </div>
                {/each}
              {:else}
                <p
                  style="color: var(--text-muted); font-size: 0.9rem; padding: 12px 0; text-align: center;"
                >
                  {t("mgt_no_employees", "No employees hired yet.")}
                </p>
              {/if}
            </div>
          </div>

          <div class="panel-card">
            <h3 class="panel-title">
              <i class="fa-solid fa-user-plus"></i>
              {t("mgt_hire_title", "Hire Employee")}
            </h3>
            <p style="font-size: 0.85rem; color: var(--text-muted);">
              {t(
                "mgt_hire_desc",
                "Enter the player's Server ID to hire them as staff.",
              )}
            </p>
            <div
              class="rename-form"
              style="display: flex; flex-direction: column; gap: 12px;"
            >
              <input
                type="number"
                class="input-field"
                placeholder={t("mgt_hire_placeholder", "Enter Server ID...")}
                bind:value={hireServerId}
                min="1"
              />
              <button
                class="primary-btn"
                onclick={hireEmployee}
                disabled={!hireServerId || hireServerId <= 0}
              >
                {t("btn_hire", "Hire")}
              </button>
            </div>
          </div>
        </div>
      </div>
    {/if}

    {#if activeTab === "sell"}
      <div class="tab-content">
        <div class="sell-warning-card">
          <i class="fa-solid fa-triangle-exclamation"></i>
          <h3>{t("mgt_sell_title", "Abandon Station Venture")}</h3>
          <p>
            {t(
              "mgt_sell_desc",
              "Liquidating ownership returns the station back to the public market. You will lose access to the logistics terminal, stock reserves, and active upgrades immediately.",
            )}
          </p>

          <div class="refund-estimate">
            {t(
              "mgt_sell_estimate",
              "Liquidation Refund Estimate: %s",
              "$" + calculatedRefund.toLocaleString(),
            )}
          </div>

          <button class="sell-btn" onclick={sellStation}>
            {t("mgt_sell_btn", "Liquidate Station Assets")}
          </button>
        </div>
      </div>
    {/if}
  </main>
</div>

<style>
  @import "./ManagementUI.css";
</style>
