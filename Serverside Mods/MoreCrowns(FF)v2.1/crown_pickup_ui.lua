_G.CrownPickupUI = {
	css = "gui/default_css",
	type = "container",
	size = {"100%", "100%"},
	children = {
		{
			id = "crown_popup",
			position = {
				"center",
				"top + 50",
			},
			type = "container",
			visible = false,
			size = {
				"1100",
				"450",
			},
			children = {
				{
					bg_img = "portal_plate",
					position = {
						"center",
						"center",
					},
					size = {
						"100%",
						"100%",
					},
				},
				{
					position = {
						"center",
						"center",
					},
					size = {
						"100%",
						"160",
					},
					children = {
						{
							font_size = 36,
							id = "crown_text_title",
							text = "Crowns Picked Up",
							text_align = "center",
							position = {
								"center",
								"top + 10",
							},
							size = {
								"100%",
								"30",
							},
						},
						{
							font_size = 22,
							id = "crown_player_1",
							text = "",
							text_align = "center",
							visible = false,
							position = {
								"center",
								"top + 50",
							},
							size = {
								"100%",
								"25",
							},
						},
						{
							font_size = 22,
							id = "crown_player_2",
							text = "",
							text_align = "center",
							visible = false,
							position = {
								"center",
								"top + 80",
							},
							size = {
								"100%",
								"25",
							},
						},
						{
							font_size = 22,
							id = "crown_player_3",
							text = "",
							text_align = "center",
							visible = false,
							position = {
								"center",
								"top + 110",
							},
							size = {
								"100%",
								"25",
							},
						},
						{
							font_size = 22,
							id = "crown_player_4",
							text = "",
							text_align = "center",
							visible = false,
							position = {
								"center",
								"top + 140",
							},
							size = {
								"100%",
								"25",
							},
						},
					},
				},
			},
		},
	},
}