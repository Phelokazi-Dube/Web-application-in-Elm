defmodule WaterWeeds.Migration.ImporterConfigTest do
  use ExUnit.Case, async: true

  alias WaterWeeds.Migration.Importer

  test "water hyacinth readings have a composite identity" do
    assert Importer.import_config()["WHMeasurementsReadings"].identity ==
             ["whmid", "plantNumber"]
  end

  test "Implementers uses the same required-sheet rules as other collections" do
    config = Importer.import_config()["Implementers"]

    assert config.collection == "Implementers"
    assert config.identity == ["implementerId"]
    refute Map.has_key?(config, :optional?)
  end

  test "unverified Sites and WHMCounter remain excluded" do
    refute Map.has_key?(Importer.import_config(), "Sites")
    refute Map.has_key?(Importer.import_config(), "whmcounter")
  end
end
