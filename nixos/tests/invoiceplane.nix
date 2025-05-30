{ pkgs, ... }:

{
  name = "invoiceplane";
  meta = with pkgs.lib.maintainers; {
    maintainers = [
      onny
    ];
  };

  nodes = {
    invoiceplane_caddy =
      { ... }:
      {
        services.invoiceplane.webserver = "caddy";
        services.invoiceplane.sites = {
          "site1.local" = {
            database.name = "invoiceplane1";
            database.createLocally = true;
            enable = true;
          };
          "site2.local" = {
            database.name = "invoiceplane2";
            database.createLocally = true;
            enable = true;
          };
        };

        networking.firewall.allowedTCPPorts = [ 80 ];
        networking.hosts."127.0.0.1" = [
          "site1.local"
          "site2.local"
        ];
      };

    invoiceplane_nginx =
      { ... }:
      {
        services.invoiceplane.webserver = "nginx";
        services.invoiceplane.sites = {
          "site1.local" = {
            database.name = "invoiceplane1";
            database.createLocally = true;
            enable = true;
          };
          "site2.local" = {
            database.name = "invoiceplane2";
            database.createLocally = true;
            enable = true;
          };
        };

        networking.firewall.allowedTCPPorts = [ 80 ];
        networking.hosts."127.0.0.1" = [
          "site1.local"
          "site2.local"
        ];
      };
  };

  testScript = ''
    start_all()

    invoiceplane_caddy.wait_for_unit("caddy")
    invoiceplane_nginx.wait_for_unit("nginx")

    site_names = ["site1.local", "site2.local"]

    machines = [invoiceplane_caddy, invoiceplane_nginx]

    for machine in machines:
      machine.wait_for_open_port(80)
      machine.wait_for_open_port(3306)

      for site_name in site_names:
          machine.wait_for_unit(f"phpfpm-invoiceplane-{site_name}")

          with subtest("Website returns welcome screen"):
              assert "Please install InvoicePlane" in machine.succeed(f"curl -L {site_name}")

          with subtest("Finish InvoicePlane setup"):
            machine.succeed(
              f"curl -sSfL --cookie-jar cjar {site_name}/setup/language"
            )
            csrf_token = machine.succeed(
              "grep ip_csrf_cookie cjar | cut -f 7 | tr -d '\n'"
            )
            machine.succeed(
              f"curl -sSfL --cookie cjar --cookie-jar cjar -d '_ip_csrf={csrf_token}&ip_lang=english&btn_continue=Continue' {site_name}/setup/language"
            )
            csrf_token = machine.succeed(
              "grep ip_csrf_cookie cjar | cut -f 7 | tr -d '\n'"
            )
            machine.succeed(
              f"curl -sSfL --cookie cjar --cookie-jar cjar -d '_ip_csrf={csrf_token}&btn_continue=Continue' {site_name}/setup/prerequisites"
            )
            csrf_token = machine.succeed(
              "grep ip_csrf_cookie cjar | cut -f 7 | tr -d '\n'"
            )
            machine.succeed(
              f"curl -sSfL --cookie cjar --cookie-jar cjar -d '_ip_csrf={csrf_token}&btn_continue=Continue' {site_name}/setup/configure_database"
            )
            csrf_token = machine.succeed(
              "grep ip_csrf_cookie cjar | cut -f 7 | tr -d '\n'"
            )
            machine.succeed(
              f"curl -sSfl --cookie cjar --cookie-jar cjar -d '_ip_csrf={csrf_token}&btn_continue=Continue' {site_name}/setup/install_tables"
            )
            csrf_token = machine.succeed(
              "grep ip_csrf_cookie cjar | cut -f 7 | tr -d '\n'"
            )
            machine.succeed(
              f"curl -sSfl --cookie cjar --cookie-jar cjar -d '_ip_csrf={csrf_token}&btn_continue=Continue' {site_name}/setup/upgrade_tables"
            )
  '';
}
