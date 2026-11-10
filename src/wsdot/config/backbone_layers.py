# Core Backbone Configuration for TPS3 / TPS4 Data Stewardship
WSDOT_TPS_BACKBONE_LAYERS = {
    # 1. Core LRS, Mileposts, and State Infrastructure
    "lrs_core": {
        "state_route_lrs": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/LRSData/FeatureServer/9",
        "state_route_increasing_24k": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/LRSData/FeatureServer/0",
        "state_route_decreasing_24k": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/LRSData/FeatureServer/1",
        "milepost_tenth_mile": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/MilepostValues/FeatureServer/3",
        "crab_rts": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/CRABRoutes/FeatureServer/0",
        "counties": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/CountyBoundaries/FeatureServer/0",
        "cities": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/CityLimits/MapServer/2",
    },
    
    # 2. Public & Local Agency Roads
    "public_roads": {
        "local_public_roads": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/WSDOTPublicRoads/MapServer/6",
        "local_pub_roads_rt": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/LocalAgencyPublicRoadData/FeatureServer/1",
    },
    
    # 3. Essential Roadway Characteristics (State Highway Log)
    "roadway_characteristics": {
        "lane_information": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/RoadwayCharacteristicData/FeatureServer/3",
        "legal_speed_limits": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/RoadwayCharacteristicData/FeatureServer/4",
        "surface_type": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/RoadwayCharacteristicData/FeatureServer/11",
        "shoulders": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/RoadwayCharacteristicData/FeatureServer/9",
    },

    # 4. Critical Structures & Traffic Operations
    "operations_and_assets": {
        "all_bridge_and_tunnel_inventory_state_local": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/BridgeData/FeatureServer/2",
        "traffic_counts": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/TrafficData/FeatureServer/0",
        "traffic_sections": "https://data.wsdot.wa.gov/arcgis/rest/services/Shared/TrafficData/FeatureServer/1",
    }
}
