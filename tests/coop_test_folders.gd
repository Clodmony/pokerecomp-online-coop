extends GutHookScript

## Run before every suite (`.gutconfig.json`): the tests share the player's user folder, so campaigns and session logs
## go elsewhere: a test once deleted the campaigns, and logs past thirty push out the ones that can restore them.

const CAMPAIGNS: String = "user://coop_campaigns_test"
const LOGS: String = "user://coop_logs_test"


func run() -> void:
	PokeCoopSession.campaigns_dir = CAMPAIGNS
	PokeCoopLog.logs_folder = LOGS
