extends Node

var selected_character := "res://assets/characters/Blank_Character/Blank_Character.glb"
var selected_color: Color = Color(0.95, 0.95, 0.95)
var selected_face: String = "res://assets/characters/face/robloxmanface.png"
var selected_hat: String = ""
var has_selected_character: bool = false
var is_hosting := false
var minigame_players: Dictionary = {}

var campaign_active := false
var wins_to_win := 3
var target_score: int = 5000
var campaign_map_mode := "manual"
var pending_match_winner := -1
var player_wins: Dictionary = {}
var player_scores: Dictionary = {}
var round_scores: Dictionary = {}
var elimination_order: Array[int] = []
var last_played_map: String = ""


func reset_campaign_scores() -> void:
	player_wins.clear()
	player_scores.clear()
	round_scores.clear()
	elimination_order.clear()
	pending_match_winner = -1
	last_played_map = ""


