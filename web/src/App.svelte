<script>
  import { onMount } from "svelte";
  import ManagementUI from "./components/ManagementUI.svelte";
  import FuelPumpUI from "./components/FuelPumpUI.svelte";

  let visible = $state(false);
  /** @type {any} */
  let station = $state(null);
  /** @type {any} */
  let config = $state(null);

  let pumpActive = $state(false);
  /** @type {any} */
  let pumpData = $state(null);

  /** @type {any} */
  let locales = $state({});

  /**
   * Translates a key with arguments and a fallback
   * @param {string} key
   * @param {string} fallback
   * @param {any[]} args
   * @returns {string}
   */
  function t(key, fallback = "", ...args) {
    let str = locales[key] || fallback;
    if (args.length > 0) {
      args.forEach((arg) => {
        str = str.replace("%s", arg);
      });
    }
    return str;
  }

  onMount(() => {
    if (!("invokeNative" in window)) {
      const dev_show_pump_ui = false;
      const dev_show_management_ui = true;

      config = {
        minPrice: 1,
        maxPrice: 20,
        aiDispatchFee: 250,
        theme: {
          primary: "#6fd2f3",
          primaryDark: "#4fb9dd",
          primaryText: "#0f0f10",
        },
        stockOrders: [
          { label: "Small Tanker", amount: 1000, price: 3000 },
          { label: "Medium Tanker", amount: 5000, price: 14000 },
          { label: "Large Tanker", amount: 10000, price: 27000 },
        ],
        upgrades: {
          capacity: {
            title: "Storage Capacity",
            description:
              "Increase the maximum amount of fuel your station can hold.",
            levels: [
              { value: 15000, price: 50000 },
              { value: 25000, price: 125000 },
            ],
          },
          shippingDiscount: {
            title: "Shipping Discount",
            description: "Lower import costs for fuel shipments.",
            levels: [
              { value: 0.1, price: 30000 },
              { value: 0.2, price: 75000 },
              { value: 0.3, price: 150000 },
            ],
          },
          hiredDriver: {
            enabled: true,
            title: "Logistics Dispatch Contract",
            description:
              "Contract professional truck drivers to automatically fetch and deliver your stock orders over time.",
            levels: [
              { level: 1, value: 600, price: 15000 },
              { level: 2, value: 420, price: 25000 },
              { level: 3, value: 300, price: 40000 },
            ],
          },
        },
      };

      if (dev_show_management_ui) {
        station = {
          id: "LNS_TEST",
          name: "LumaNode Station",
          balance: 150000,
          stock: 5000,
          capacity: 10000,
          price: 5,
          role: "owner",
          upgrades: {
            capacity: 1,
            shippingDiscount: 1,
            hiredDriver: 0,
          },
          statistics: {
            totalSales: 1500,
            totalRevenue: 7500,
            lifetimeClients: 42,
          },
          employees: [
            { name: "John Doe", identifier: "ABC12345", role: "employee" },
            { name: "Jane Smith", identifier: "XYZ67890", role: "employee" },
          ],
        };
        visible = true;
      }

      if (dev_show_pump_ui) {
        pumpData = {
          stationName: "LumaNode Station",
          vehicleName: "Vapid Dominator",
          fuelLabel: "Unleaded",
          pricePerLiter: 5,
          currentFuel: 40,
          maxFuel: 65,
          playerMoney: 500,
          stockLeft: 200,
          theme: config.theme,
        };
        pumpActive = true;
      }
    }

    /** @param {any} event */
    const handleMessage = (event) => {
      const data = event.data;

      if (data.action === "openUI") {
        try {
          locales = data.locales || {};
          station = data.station;
          config = data.config;
          visible = true;
        } catch (e) {
          console.error("[LNS_Fuel] Error opening UI:", e);
          fetch(`https://LNS_Fuel/closeUI`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({}),
          });
        }
      } else if (data.action === "openPumpUI") {
        try {
          locales = data.locales || {};
          pumpData = data.data;
          if (pumpData.theme) {
            config = { theme: pumpData.theme };
          }
          pumpActive = true;
        } catch (e) {
          console.error("[LNS_Fuel] Error opening Pump UI:", e);
          fetch(`https://LNS_Fuel/closePumpUI`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({}),
          });
        }
      } else if (data.action === "updateUI") {
        if (
          visible &&
          station &&
          data.station &&
          data.station.id === station.id
        ) {
          const currentRole = station.role;
          station = { ...data.station, role: currentRole };
        }
      }
    };

    /** @param {any} event */
    const handleKeyDown = (event) => {
      if (event.key === "Escape") {
        if (visible) {
          closeUI();
        } else if (pumpActive) {
          closePumpUI();
        }
      }
    };

    window.addEventListener("message", handleMessage);
    window.addEventListener("keydown", handleKeyDown);

    return () => {
      window.removeEventListener("message", handleMessage);
      window.removeEventListener("keydown", handleKeyDown);
    };
  });

  function closeUI() {
    visible = false;
    fetch(`https://LNS_Fuel/closeUI`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    });
  }

  function closePumpUI() {
    pumpActive = false;
    fetch(`https://LNS_Fuel/closePumpUI`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    });
  }

  /** @param {number} liters */
  function startRefueling(liters) {
    pumpActive = false;
    fetch(`https://LNS_Fuel/startRefueling`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ liters }),
    });
  }
</script>

<div
  class="app-container"
  class:visible={visible || pumpActive}
  style="
    --color-primary: {config?.theme?.primary ?? '#ffffff'};
    --color-primary-dark: {config?.theme?.primaryDark ?? '#e4e4e7'};
    --color-primary-text: {config?.theme?.primaryText ?? '#0f0f10'};
  "
>
  {#if visible && station && config}
    <ManagementUI bind:station {config} {closeUI} {t} />
  {/if}

  {#if pumpActive && pumpData}
    <FuelPumpUI {pumpData} {config} {closePumpUI} {startRefueling} {t} />
  {/if}
</div>
