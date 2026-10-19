extends Node

var selected_character := "res://assets/characters/Blank_Character/Blank_Character.glb"
var selected_color: Color = Color(0.95, 0.95, 0.95)
var selected_face: String = "res://assets/characters/face/robloxmanface.png"
var selected_hat: String = ""
var is_hosting := false
var minigame_players: Dictionary = {}

var campaign_active := false
var wins_to_win := 3
var campaign_map_mode := "manual"
var pending_match_winner := -1

