let theme = {
  rosewater: "#f5e0dc"
  flamingo: "#f2cdcd"
  pink: "#f5c2e7"
  mauve: "#cba6f7"
  red: "#f38ba8"
  maroon: "#eba0ac"
  peach: "#fab387"
  yellow: "#f9e2af"
  green: "#a6e3a1"
  teal: "#94e2d5"
  sky: "#89dceb"
  sapphire: "#74c7ec"
  blue: "#89b4fa"
  lavender: "#b4befe"
  text: "#cdd6f4"
  subtext1: "#bac2de"
  subtext0: "#a6adc8"
  overlay2: "#9399b2"
  overlay1: "#7f849c"
  overlay0: "#6c7086"
  surface2: "#585b70"
  surface1: "#45475a"
  surface0: "#313244"
  base: "#1e1e2e"
  mantle: "#181825"
  crust: "#11111b"
}

let scheme = {
  recognized_command: $theme.blue
  unrecognized_command: $theme.text
  constant: $theme.peach
  punctuation: $theme.overlay2
  operator: $theme.sky
  string: $theme.green
  virtual_text: $theme.surface2
  variable: { fg: $theme.flamingo attr: i }
  filepath: $theme.yellow
}

def hex-to-rgb [hex:string] {
  let raw = ($hex | str trim | str downcase | str replace -r '^#' '')
  let normalized = match ($raw | str length) {
    3 => ($raw | split chars | each {|c| $"($c)($c)"} | str join)
    6 => $raw
  }

  return {
    r: ($normalized | str substring 0..1 | into int -r 16)
    g: ($normalized | str substring 2..3 | into int -r 16)
    b: ($normalized | str substring 4..5 | into int -r 16)
  }
}

# Estimate Ys (screen luminance) using sRGB coefficients per APCA-W3
def apca-Ys [color:record<r:int g:int b:int>] {
  let s_trc = 2.4 # APCA constant

  let Rs = ((($color.r / 255.0) ** $s_trc) * 0.2126729)
  let Gs = ((($color.g / 255.0) ** $s_trc) * 0.7151522)
  let Bs = ((($color.b / 255.0) ** $s_trc) * 0.0721750)

  return ($Rs + $Gs + $Bs)
}

# Soft clip and clamp black levels
def apca-softclip [Yc:float] {
  # APCA constants
  let B_clip = 1.414
  let B_thrsh = 0.022

  if $Yc < 0.0 {
    return 0.0
  } else if $Yc < $B_thrsh {
    return ($Yc + (($B_thrsh - $Yc) ** $B_clip))
  } else {
    return $Yc
  }
}

# Main: APCA Lc (lightness contrast) for text HEX on background HEX
def apca-Lc [text_hex:string, bg_hex:string] {
  # APCA constants for 0.0.98G-4g-sRGB
  let Ntx = 0.57
  let Nbg = 0.56
  let Rtx = 0.62
  let Rbg = 0.65
  let W_scale = 1.14
  let W_offset = 0.027
  let W_clamp = 0.1

  let txt_Ys = (apca-Ys (hex-to-rgb $text_hex))
  let bg_Ys = (apca-Ys (hex-to-rgb $bg_hex))

  let Ytxt = (apca-softclip $txt_Ys)
  let Ybg = (apca-softclip $bg_Ys)

  # Apply exponents based on polarity, then always BG - TXT
  let Cw = (
    if $Ybg > $Ytxt {
      # Dark text on light background
      (($Ybg ** $Nbg) - ($Ytxt ** $Ntx)) * $W_scale
    } else {
      # Light text on dark background
      (($Ybg ** $Rbg) - ($Ytxt ** $Rtx)) * $W_scale
    })

  # Clamp minimum contrast and offset according to polarity
  let Sapc = (
    if ($Cw | math abs) < $W_clamp {
      0.0
    } else if $Cw > 0.0 {
      $Cw - $W_offset
    } else {
      $Cw + $W_offset
    })

  return ($Sapc * 100)
}

let hex_string_rule = {||
  if not ($in =~ '^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$') {
    $scheme.string
  } else {
    # normalize #RGB to #RRGGBB
    let hex = (if ($in | str length) == 4 {
      $in | str replace -r '^#(.)(.)(.)$' '#$1$1$2$2$3$3'
    } else { $in })

    # Calculate APCA contrast between hex color and background
    let contrast_lc = (apca-Lc $hex $theme.base)

    # Use APCA Lc 60 for good contrast ratio
    if ($contrast_lc | math abs) >= 45.0 {
      { fg: $hex }
    } else {
      # Pick appropriate text color based on which gives better contrast
      let text_contrast = (apca-Lc $theme.text $hex)
      let base_contrast = (apca-Lc $theme.base $hex)

      let text_fg = (if ($text_contrast | math abs) >= ($base_contrast | math abs) {
        $theme.text
      } else {
        $theme.base
      })

      return { fg: $text_fg bg: $hex }
    }
  }
}

$env.config.color_config = {
  separator: { fg: $theme.surface2 attr: b }
  leading_trailing_space_bg: { fg: $theme.lavender attr: u }
  header: { fg: $theme.text attr: b }
  row_index: $scheme.virtual_text
  record: $theme.text
  list: $theme.text
  hints: $scheme.virtual_text
  search_result: { fg: $theme.base bg: $theme.yellow }
  shape_closure: $theme.teal
  closure: $theme.teal
  shape_flag: { fg: $theme.maroon attr: i }
  shape_matching_brackets: { attr: u }
  shape_garbage: $theme.red
  shape_keyword: $theme.mauve
  shape_match_pattern: $theme.green
  shape_signature: $theme.teal
  shape_table: $scheme.punctuation
  cell-path: $scheme.punctuation
  shape_list: $scheme.punctuation
  shape_record: $scheme.punctuation
  shape_vardecl: $scheme.variable
  shape_variable: $scheme.variable
  empty: { attr: n }
  filesize: {||
    if $in < 1kb {
      $theme.teal
    } else if $in < 10kb {
      $theme.green
    } else if $in < 100kb {
      $theme.yellow
    } else if $in < 10mb {
      $theme.peach
    } else if $in < 100mb {
      $theme.maroon
    } else if $in < 1gb {
      $theme.red
    } else {
      $theme.mauve
    }
  }
  duration: {||
    if $in < 1day {
      $theme.teal
    } else if $in < 1wk {
      $theme.green
    } else if $in < 4wk {
      $theme.yellow
    } else if $in < 12wk {
      $theme.peach
    } else if $in < 24wk {
      $theme.maroon
    } else if $in < 52wk {
      $theme.red
    } else {
      $theme.mauve
    }
  }
  date: {|| (date now) - $in |
    if $in < 1day {
      $theme.teal
    } else if $in < 1wk {
      $theme.green
    } else if $in < 4wk {
      $theme.yellow
    } else if $in < 12wk {
      $theme.peach
    } else if $in < 24wk {
      $theme.maroon
    } else if $in < 52wk {
      $theme.red
    } else {
      $theme.mauve
    }
  }
  shape_external: $scheme.unrecognized_command
  shape_internalcall: $scheme.recognized_command
  shape_external_resolved: $scheme.recognized_command
  shape_block: $scheme.recognized_command
  block: $scheme.recognized_command
  shape_custom: $theme.pink
  custom: $theme.pink
  background: $theme.base
  foreground: $theme.text
  cursor: { bg: $theme.rosewater fg: $theme.base }
  shape_range: $scheme.operator
  range: $scheme.operator
  shape_pipe: $scheme.operator
  shape_operator: $scheme.operator
  shape_redirection: $scheme.operator
  glob: $scheme.filepath
  shape_directory: $scheme.filepath
  shape_filepath: $scheme.filepath
  shape_glob_interpolation: $scheme.filepath
  shape_globpattern: $scheme.filepath
  shape_int: $scheme.constant
  int: $scheme.constant
  bool: $scheme.constant
  float: $scheme.constant
  nothing: $scheme.constant
  binary: $scheme.constant
  shape_nothing: $scheme.constant
  shape_bool: $scheme.constant
  shape_float: $scheme.constant
  shape_binary: $scheme.constant
  shape_datetime: $scheme.constant
  shape_literal: $scheme.constant
  string: $hex_string_rule
  shape_string: $scheme.string
  shape_string_interpolation: $theme.flamingo
  shape_raw_string: $scheme.string
  shape_externalarg: $scheme.string
}
$env.config.highlight_resolved_externals = true
$env.config.explore = {
    status_bar_background: { fg: $theme.text, bg: $theme.mantle },
    command_bar_text: { fg: $theme.text },
    highlight: { fg: $theme.base, bg: $theme.yellow },
    status: {
        error: $theme.red,
        warn: $theme.yellow,
        info: $theme.blue,
    },
    selected_cell: { bg: $theme.blue fg: $theme.base },
}
