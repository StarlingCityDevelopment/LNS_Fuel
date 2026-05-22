<script>
  let { pumpData, config, closePumpUI, startRefueling, t } = $props();

  let customLiters = $state(10);
  let initialized = $state(false);

  $effect(() => {
    if (pumpData && !initialized) {
      initialized = true;

      const maxFuelToPump = 100 - pumpData.currentFuel;
      const maxAffordable = Math.floor(
        pumpData.playerMoney / pumpData.pricePerLiter,
      );
      const maxAllowed = Math.min(
        maxFuelToPump,
        maxAffordable,
        pumpData.stockLeft,
      );

      customLiters = Math.min(10, Math.floor(maxFuelToPump));
      if (customLiters <= 0) customLiters = 1;
      if (customLiters > maxAllowed) customLiters = maxAllowed;
    }
  });

  let maxFuelToPump = $derived(pumpData ? 100 - pumpData.currentFuel : 0);
  let maxAffordableLiters = $derived(
    pumpData ? Math.floor(pumpData.playerMoney / pumpData.pricePerLiter) : 0,
  );
  let maxAllowedLiters = $derived(
    pumpData
      ? Math.min(maxFuelToPump, maxAffordableLiters, pumpData.stockLeft)
      : 0,
  );
  let projectedFuelPercentage = $derived(
    pumpData ? Math.min(100, pumpData.currentFuel + customLiters) : 0,
  );
  let calculatedCost = $derived(
    pumpData ? Math.ceil(customLiters * pumpData.pricePerLiter) : 0,
  );

  /** @param {number} amount */
  function selectPresetLiters(amount) {
    if (!pumpData) return;
    customLiters = Math.min(maxAllowedLiters, Number(customLiters) + amount);
  }

  /** @param {any} liters */
  function setPresetLiters(liters) {
    if (!pumpData) return;
    if (liters === "full") {
      customLiters = maxAllowedLiters;
    } else {
      customLiters = Math.min(maxAllowedLiters, Number(liters));
    }
  }

  /** @param {number} dollars */
  function setPresetDollars(dollars) {
    if (!pumpData) return;
    const liters = Math.floor(dollars / pumpData.pricePerLiter);
    customLiters = Math.min(maxAllowedLiters, liters);
  }

  function handleRefuel() {
    if (customLiters <= 0) return;
    startRefueling(customLiters);
  }
</script>

<div class="pump-card">
  <header class="pump-header">
    <div class="brand-section">
      <div class="brand-icon">
        <i class="fa-solid fa-gas-pump"></i>
      </div>
      <div class="brand-details">
        <h2>{pumpData.stationName}</h2>
      </div>
    </div>
    <div class="pump-price-badge">
      ${pumpData.pricePerLiter.toFixed(2)}/L
    </div>
  </header>

  <div class="pump-content">
    <div class="pump-left-col">
      <div class="pump-gauge-card">
        <h3>{t("pump_fuel_level_preview", "Fuel Level Preview")}</h3>

        <div class="fuel-gauge-container">
          <svg class="fuel-gauge-svg" width="140" height="140">
            <circle class="fuel-gauge-bg" cx="70" cy="70" r="58" />
            <circle
              class="fuel-gauge-fill projected"
              cx="70"
              cy="70"
              r="58"
              stroke-dasharray="364.4"
              stroke-dashoffset={364.4 * (1 - projectedFuelPercentage / 100)}
            />
            <circle
              class="fuel-gauge-fill current"
              cx="70"
              cy="70"
              r="58"
              stroke-dasharray="364.4"
              stroke-dashoffset={364.4 * (1 - pumpData.currentFuel / 100)}
            />
          </svg>
          <div class="fuel-gauge-text">
            <span class="fuel-percentage">{projectedFuelPercentage}%</span>
            <p class="fuel-label">{t("pump_projected", "PROJECTED")}</p>
          </div>
        </div>

        <div class="vehicle-details">
          <span class="veh-name">{pumpData.vehicleName}</span>
          <span class="veh-status"
            >{t(
              "pump_current_level",
              "Current Level: %s%",
              pumpData.currentFuel,
            )}</span
          >
        </div>
      </div>
    </div>

    <div class="pump-right-col">
      <div class="selector-section">
        <span class="section-label"
          >{t("pump_liters_presets", "Liters Presets")}</span
        >
        <div class="presets-grid">
          <button
            class="preset-chip"
            onclick={() => selectPresetLiters(10)}
            disabled={maxAllowedLiters <= 0 ||
              customLiters + 10 > maxAllowedLiters}>+10L</button
          >
          <button
            class="preset-chip"
            onclick={() => selectPresetLiters(20)}
            disabled={maxAllowedLiters <= 0 ||
              customLiters + 20 > maxAllowedLiters}>+20L</button
          >
          <button
            class="preset-chip"
            onclick={() => selectPresetLiters(50)}
            disabled={maxAllowedLiters <= 0 ||
              customLiters + 50 > maxAllowedLiters}>+50L</button
          >
          <button
            class="preset-chip primary"
            onclick={() => setPresetLiters("full")}
            disabled={maxAllowedLiters <= 0 || customLiters >= maxAllowedLiters}
            >{t("pump_full_tank", "Full Tank")}</button
          >
        </div>
      </div>

      <div class="selector-section">
        <span class="section-label"
          >{t("pump_prepay_dollar_presets", "Pre-Pay Dollar Presets")}</span
        >
        <div class="presets-grid">
          <button
            class="preset-chip"
            onclick={() => setPresetDollars(10)}
            disabled={maxAllowedLiters <= 0 || pumpData.playerMoney < 10}
            >$10</button
          >
          <button
            class="preset-chip"
            onclick={() => setPresetDollars(20)}
            disabled={maxAllowedLiters <= 0 || pumpData.playerMoney < 20}
            >$20</button
          >
          <button
            class="preset-chip"
            onclick={() => setPresetDollars(50)}
            disabled={maxAllowedLiters <= 0 || pumpData.playerMoney < 50}
            >$50</button
          >
          <button
            class="preset-chip"
            onclick={() => setPresetDollars(100)}
            disabled={maxAllowedLiters <= 0 || pumpData.playerMoney < 100}
            >$100</button
          >
        </div>
      </div>

      <div class="selector-section">
        <div class="slider-header">
          <span class="section-label"
            >{t("pump_custom_liters", "Custom Liters")}</span
          >
          <span class="slider-count-badge">{customLiters} L</span>
        </div>
        {#if maxAllowedLiters > 0}
          <input
            type="range"
            class="price-slider pump-slider"
            min="1"
            max={maxAllowedLiters}
            value={customLiters}
            oninput={(e) => {
              customLiters = Number(e.currentTarget.value);
            }}
          />
        {:else}
          <div class="out-of-limits-warning" style="margin-top: 8px;">
            {#if maxFuelToPump <= 0}
              {t(
                "pump_tank_already_full",
                "Vehicle fuel tank is already full!",
              )}
            {:else if maxAffordableLiters <= 0}
              {t(
                "pump_insufficient_funds",
                "You do not have enough money to purchase fuel!",
              )}
            {:else if pumpData.stockLeft <= 0}
              {t("pump_out_of_stock", "This station is out of stock!")}
            {/if}
          </div>
        {/if}
      </div>

      <div class="invoice-box">
        <div class="invoice-row">
          <span>{t("pump_unit_price", "Unit Price")}</span>
          <span>${pumpData.pricePerLiter.toFixed(2)}/L</span>
        </div>
        <div class="invoice-row">
          <span>{t("pump_volume_to_pump", "Volume to Pump")}</span>
          <span>{t("mgt_liters", "%s Liters", customLiters)}</span>
        </div>
        <div class="invoice-row">
          <span>{t("pump_total_cost", "Total Cost")}</span>
          <span class="invoice-price">${calculatedCost.toLocaleString()}</span>
        </div>
        <div class="invoice-row wallet-row">
          <span>{t("pump_wallet_funds", "Wallet Funds")}</span>
          <span>${pumpData.playerMoney.toLocaleString()}</span>
        </div>
      </div>

      <div class="pump-actions">
        <button class="close-btn" onclick={closePumpUI}
          >{t("btn_cancel", "Cancel")}</button
        >
        <button
          class="primary-btn pulse-effect"
          onclick={handleRefuel}
          disabled={customLiters <= 0}
        >
          {t("pump_btn_begin_refueling", "Begin Refueling")}
        </button>
      </div>
    </div>
  </div>
</div>

<style>
  @import "./FuelPumpUI.css";
</style>
