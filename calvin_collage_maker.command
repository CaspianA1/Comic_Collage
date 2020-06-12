#!/usr/bin/env python3
import os, random
import tkinter as tk
from tkinter import filedialog
from PIL import Image
#
#####################################################################
def load_image(image_name):
	return Image.open(image_name)

def generate_matrix(c_h_image):
	width, height = c_h_image.size
	image_data_list = list(c_h_image.getdata())
	pixel_matrix = []

	for i in range(height):
		row = []
		for j in range(width):
			row.append(image_data_list[i * width + j - 1])
		pixel_matrix.append(row)		
	return pixel_matrix

def is_white(data, row_or_pixel):
	white_variants = (
	(255, 255, 255),
	(255, 255, 250),
	(245, 255, 250),
	(248, 248, 255),
	(245, 245, 245),
	(255, 250, 240))
	if row_or_pixel == "pixel":
		pixel_clump = data
		if pixel_clump in white_variants: return True
		else: return False

	elif row_or_pixel == "row":
		row = data; white_pixels = 0
		for x_coordinate, pixel_clump in enumerate(row):
			_pixel_clump = pixel_clump
			if len(pixel_clump) == 4:
				_pixel_clump = pixel_clump[:3]
			if _pixel_clump in white_variants:
				white_pixels += 1
		percent_whiteness = white_pixels / len(row)
		line_indicator = 0.9
		if percent_whiteness > line_indicator: return True
		else: return False

def get_white_lines(c_h_image_data):
	white_y_coordinates = []
	for outer_index, row in enumerate(c_h_image_data):
		if is_white(row, "row"):
			white_y_coordinates.append(outer_index)
	return white_y_coordinates


def crop(c_h_image, white_line_coords):
	image_panels = []
	width, height = c_h_image.size
	previous_y_coord = 0
	for y_coord in white_line_coords:
		border = (0, previous_y_coord, width, y_coord)
		if y_coord - previous_y_coord in range(20): continue
		else:
			image_panels.append(c_h_image.crop(border))
			previous_y_coord = y_coord
	return image_panels


def get_all_panels(image):
	# image = load_image(image_name)
	image = image.crop((0, 10, image.size[0], image.size[1]))
	image_data = generate_matrix(image)
	white_lines = get_white_lines(image_data)
	image_pre_panels = crop(image, white_lines)

	tall_rotated_panels = [panel.transpose(Image.ROTATE_90) for panel in image_pre_panels]

	all_image_panels = []

	for panel in tall_rotated_panels:
		panel_data = generate_matrix(panel)
		white_lines = get_white_lines(panel_data)
		sub_image_panels = crop(panel, white_lines)
		for sub_image_panel in sub_image_panels:
			width, height = sub_image_panel.size
			if width / height > 3:
				continue
			all_image_panels.append(sub_image_panel)

	all_image_panels = [panel.transpose(Image.ROTATE_270) for panel in all_image_panels]
	return all_image_panels



def save_image(image, image_name):
	collage_path = os.path.dirname(os.path.realpath(__file__)) + "/Collage/"
	# print(f"COLLAGE PATH: {collage_path}")
	file_postfix = "_" + str(len(os.listdir(collage_path)) + 1)
	full_name = f"{collage_path}{image_name}{file_postfix}.png"
	try:
		image.save(full_name, "PNG")
	except AttributeError:
		pass
	return image

def line_up_images(image_row):
	try:
		widths, heights = zip(*(image.size for image in image_row))
	except ValueError:
		print("Image invalid, please try another one.")
		exit()
	total_width = sum(widths)
	max_height = max(heights)
	combined_image = Image.new("RGB", (total_width, max_height))
	x_offset = 0
	for image in image_row:
		combined_image.paste(image, (x_offset, 0))
		x_offset += image.size[0]
	return combined_image

def stack_images(image_1, image_2):
	stack_img = Image.new("RGB", (min(image_1.width, image_2.width), image_1.height + image_2.height))
	stack_img.paste(image_1, (0, 0))
	stack_img.paste(image_2, (0, image_1.height))
	return stack_img


def compare_source_img(source_image_data, panels, mode_color_groups):

	panel_dict = dict(zip(mode_color_groups, panels))
	summed_image_matrix = []
	jump_to_2nd_loop = False
	for source_row in source_image_data:
		image_row = []
		for source_pixel in source_row:
			for list_top_common_colors, image_panel in panel_dict.items():
				if jump_to_2nd_loop is True:
					jump_to_2nd_loop = False
					break
				for common_color in list_top_common_colors:
					if is_same_color(common_color, source_pixel):
						image_row.append(image_panel)
						jump_to_2nd_loop = True
						break

		summed_image_matrix.append(image_row)
	return summed_image_matrix

def shrink_matrix(matrix, scale_factor):
	scaled_matrix = []
	for outer_index in range(0, len(matrix), scale_factor):
		row = []
		for inner_index in range(0, len(matrix[0]), scale_factor):
			row.append(matrix[outer_index][inner_index])
		scaled_matrix.append(row)
	return scaled_matrix

def shrink_image(image, shr_factor):
	width, height = image.size
	sw, sh = width // shr_factor, height // shr_factor
	image.thumbnail((sw, sh), Image.ANTIALIAS)
	return image


def is_same_color(pixel_1, pixel_2):
	color_mapping = dict(zip(pixel_1, pixel_2))
	sim_components = 0
	for comp_1, comp_2 in color_mapping.items():
		color_diff = abs(comp_1 - comp_2)
		if color_diff < 10:
			sim_components += 1

	return sim_components > 1

def avg_pixels(pixel_1, pixel_2):
	averaged_pixel = []
	zipped_pixels = list(zip(pixel_1, pixel_2))
	for index in range(3):
		averaged_pixel.append(sum(zipped_pixels[index]) // len(zipped_pixels[index]))
	return averaged_pixel

def tone_to_reference(panel_series, reference_matrix, tone_factor):
	for outer_index, panel_row in enumerate(panel_series):
		for inner_index, panel in enumerate(panel_row):
			try:
				conn_ref_color = reference_matrix[outer_index][inner_index]

				mixer_img = Image.new(panel.mode, panel.size, color = conn_ref_color)
				mixed_img = Image.blend(panel, mixer_img, tone_factor)
				panel_series[outer_index][inner_index] = mixed_img

			except IndexError:
				continue

	return panel_series

def common_colors(image_data):
	color_repeats = {}
	mode_color_reps = []
	top_mode_colors = []
	for row in image_data:
		for pixel in row:
			if pixel not in color_repeats:
				color_repeats[pixel] = 1
			else:
				color_repeats[pixel] += 1
	for num_repeats in color_repeats.values():
		mode_color_reps.append(num_repeats)
	mode_color_reps = sorted(mode_color_reps)[:-21:-1]
	top_colors = []
	for times_repeated in mode_color_reps:
		for pixel, and_its_repeats in color_repeats.items():
			if times_repeated == and_its_repeats:
				top_colors.append(pixel)
	return top_colors

####################################################################################################################

def main_backend(scale_factor, tone_depth, image):


	try:
		scale_factor = int(float(scale_factor))
	except (TypeError, ValueError):
		scale_factor = random.randint(2, 6)
	try:
		tone_depth = float(tone_depth)
	except (TypeError, ValueError):
		tone_depth = random.uniform(0.5, 0.9)
	panels = get_all_panels(image)

	panel_matrices = [generate_matrix(panel) for panel in panels]
	mode_color_bindings = {}
	for panel_index, panel in enumerate(panels):
		a = panel_matrices[panel_index]
		b = tuple(common_colors(a))
		mode_color_bindings[b] = panel

	try:
		random_panel = random.choice(panels)
	except IndexError:
		print("Image invalid, please try again.")
		exit()

	random_panel_matrix = generate_matrix(random_panel)
	shrunken_panel_matrix = shrink_matrix(random_panel_matrix, scale_factor = scale_factor)

	loose_panel_collection = compare_source_img(shrunken_panel_matrix, panels, mode_color_bindings)

	loose_panel_collection = tone_to_reference(loose_panel_collection, shrunken_panel_matrix, tone_depth)

	row_img = []
	for index, row in enumerate(loose_panel_collection):
		stack = line_up_images(row)
		row_img.append(stack)

	for index in range(len(row_img)):
		row_img[index] = shrink_image(row_img[index], shr_factor = 5)

	base_stack = row_img[0]
	for index in range(len(row_img) - 1):
		forward_element = row_img[index + 1]
		temp_stack = stack_images(base_stack, forward_element)
		base_stack = temp_stack

	width, height = base_stack.size

	if height / width > 3:
		print("Process failed, trying again.")
		dir_path = os.path.dirname(os.path.realpath(__file__))
		new_img_name = random.choice(os.listdir(f"{dir_path}/Images/"))  # could change this later to new sub-panel within panel
		new_img = Image.open(f"{dir_path}/Images/{new_img_name}")
		base_stack = main_backend(scale_factor, tone_depth, new_img)

	save_image(base_stack, "collage")

	print("Success!")

#####################################################################

def choose_image():
	directory_button.config(bg = "orange", fg = "gray")
	directory_button.filename = tk.filedialog.askopenfilename(
	initialdir = "/Images/",
	title = "Select a colored graphic novel image:",
	filetypes = (("PNG Files", "*.png"), ("all files", "*.*")))

	image_path = directory_button.filename
	input_image = Image.open(image_path)
	image_name = image_path[image_path.rfind("/") + 1:]
	# input_image.save(f"Images/{image_name}")

	scale_factor = tk.Scale(
	window, from_ = 1,
	to = 10, orient = tk.HORIZONTAL,
	label = "Scale factor")
	scale_factor.place(x = 0, y = 20)

	tone_depth = tk.Scale(
	window, from_ = 1,
	to = 9, orient = tk.HORIZONTAL,
	label = "Tone depth")
	tone_depth.place(x = 0, y = 100)

	def feed_data():
		scaling_data = scale_factor.get()
		tone_data = tone_depth.get() / 10
		main_backend(scaling_data, tone_depth, input_image)

		dir_path = os.path.dirname(os.path.realpath(__file__))
		all_collages = os.listdir(f"{dir_path}/Collage/")  # may not work later when built
		try:
			all_collages.remove(".DS_Store")
		except ValueError:
			pass

		index_bindings = {}
		for collage_name in all_collages:
			underscore, period = collage_name.find("_"), collage_name.find(".")
			# try:
			collage_index = int(collage_name[underscore + 1:period])
			# except ValueError:
			# print("Settings are too extreme, please try again.")
			# exit()
			index_bindings[collage_index] = collage_name

		recent_collage = index_bindings[max(index_bindings.keys())]
		output_image = Image.open(f"{dir_path}/Collage/{recent_collage}")
		show_img = lambda: output_image.show()
		
		view_button = tk.Button(window, text = "View result:", command = show_img, fg = "orange")
		view_button.place(x = 110, y = 150)


	start_button = tk.Button(text = "Start!", command = feed_data, fg = "orange")
	# start_button.pack(side = tk.BOTTOM)
	start_button.place(x = 130, y = 170)


if __name__ == "__main__":
	window = tk.Tk()
	window.resizable(False, False)
	window.title("Calvin & Hobbes - Collage Generator")
	window.geometry("300x200")

	directory_button = tk.Button(window,
	text = "Select an image:",
	command = choose_image,
	fg = "orange")
	directory_button.pack()

	window.mainloop()
