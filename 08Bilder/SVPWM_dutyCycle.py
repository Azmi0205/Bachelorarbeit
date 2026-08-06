import numpy as np
import matplotlib.pyplot as plt


# ============================================================
# Thesis-style configuration based on the MATLAB style guide
# ============================================================

config = {
    # --------------------------------------------------------
    # Output settings
    # --------------------------------------------------------
    "output_png": "svpwm_pwm_switching_pattern.png",
    "output_pdf": "svpwm_pwm_switching_pattern.pdf",
    "save_pdf": False,
    "dpi": 500,

    "fig_width_cm": 52,
    "fig_height_cm": 36,

    # --------------------------------------------------------
    # SVPWM segment configuration
    # --------------------------------------------------------
    # Seven-segment sequence:
    # V0 -> V1 -> V2 -> V7 -> V2 -> V1 -> V0
    #
    # All segment widths are intentionally equal.
    "segment_widths": [1, 1, 1, 1, 1, 1, 1],

    "segment_labels": [
        r"$t_0/2$",
        r"$t_1/2$",
        r"$t_2/2$",
        r"$t_7$",
        r"$t_2/2$",
        r"$t_1/2$",
        r"$t_0/2$",
    ],

    "vector_labels": [
        r"$V_0$",
        r"$V_1$",
        r"$V_2$",
        r"$V_7$",
        r"$V_2$",
        r"$V_1$",
        r"$V_0$",
    ],

    # Show only voltage-vector labels, not segment duration labels
    "show_segment_labels": False,
    "show_vector_labels": True,
    "show_period_arrow": False,
    "show_title": False,

    # --------------------------------------------------------
    # Colors from MATLAB style guide
    # --------------------------------------------------------
    "colors": {
        "a": (0.85, 0.10, 0.10),
        "b": (0.10, 0.55, 0.10),
        "c": (0.10, 0.25, 0.85),
        "grid": (0.0, 0.0, 0.0),
        "text": (0.0, 0.0, 0.0),
    },

    # --------------------------------------------------------
    # Line widths from MATLAB style guide
    # --------------------------------------------------------
    "lw": 4,
    "grid_lw": 3.0,
    "axis_lw": 3.0,

    # Short dashed vertical lines
    "grid_linestyle": (0, (2.5, 2.5)),

    # --------------------------------------------------------
    # Font sizes from MATLAB style guide
    # --------------------------------------------------------
    "fs_title": 30,
    "fs_axis": 25,
    "fs_leg": 25,
    "fs_label": 27,

    "fs_pwm_label": 60,
    "fs_duration": 35,
    "fs_vector": 40,

    # --------------------------------------------------------
    # Trace labels
    # --------------------------------------------------------
    "pwm_labels": {
        "a": r"$PWM_a$",
        "b": r"$PWM_b$",
        "c": r"$PWM_c$",
    },

    # --------------------------------------------------------
    # Vertical trace levels
    # --------------------------------------------------------
    "trace_levels": {
        "c": {"low": 2.30, "high": 2.95},
        "b": {"low": 1.40, "high": 2.05},
        "a": {"low": 0.50, "high": 1.15},
    },

    # --------------------------------------------------------
    # Layout and axes
    # --------------------------------------------------------
    "x_margin": 0.03,
    "y_limits": (-0.25, 3.35),

    # Segment duration label position
    "duration_label_y": 0.25,

    # Voltage-vector label position
    "vector_label_y": 3.17,

    # Optional title
    "title": r"Center-aligned SVPWM switching pattern",

    # Optional period arrow
    "period_arrow_y": 0.08,
    "period_label_y": -0.06,
    "period_label": r"$T_{\mathrm{PWM}}$",
}


# ============================================================
# Switching-state definition
# ============================================================

# Sector-I seven-segment sequence:
#
# V0 = 000
# V1 = 100
# V2 = 110
# V7 = 111
# V2 = 110
# V1 = 100
# V0 = 000

switching_states = {
    "a": [0, 1, 1, 1, 1, 1, 0],
    "b": [0, 0, 1, 1, 1, 0, 0],
    "c": [0, 0, 0, 1, 0, 0, 0],
}


# ============================================================
# Helper functions
# ============================================================

def cm_to_inches(value_cm):
    return value_cm / 2.54


def configure_matplotlib_style(config):
    """
    Configure Matplotlib to approximate the thesis-style MATLAB settings.
    """

    plt.rcParams.update({
        "figure.facecolor": "white",
        "axes.facecolor": "white",
        "savefig.facecolor": "white",

        # LaTeX-like math rendering without requiring a full LaTeX installation
        "mathtext.fontset": "cm",
        "font.family": "serif",

        # General font and axis styling
        "font.size": config["fs_axis"],
        "axes.linewidth": config["axis_lw"],

        # Export quality
        "savefig.dpi": config["dpi"],
    })


# ============================================================
# Figure generation
# ============================================================

def plot_svpwm_switching_pattern(config, switching_states):
    configure_matplotlib_style(config)

    # Convert MATLAB-style centimeter figure size to inches
    fig_width_in = cm_to_inches(config["fig_width_cm"])
    fig_height_in = cm_to_inches(config["fig_height_cm"])

    # Normalize segment widths
    segment_widths = np.array(config["segment_widths"], dtype=float)
    segment_widths = segment_widths / np.sum(segment_widths)

    bounds = np.concatenate(([0.0], np.cumsum(segment_widths)))
    centers = 0.5 * (bounds[:-1] + bounds[1:])

    fig, ax = plt.subplots(figsize=(fig_width_in, fig_height_in))

    # --------------------------------------------------------
    # Vertical dashed switching boundaries
    # --------------------------------------------------------
    for x in bounds:
        ax.axvline(
            x,
            color=config["colors"]["grid"],
            linestyle=config["grid_linestyle"],
            linewidth=config["grid_lw"],
            ymin=0.13,
            ymax=0.91,
            zorder=0,
        )

    # --------------------------------------------------------
    # PWM waveforms
    # --------------------------------------------------------
    # Order chosen to match the visual arrangement:
    # top: PWM_c, middle: PWM_b, bottom: PWM_a
    for phase in ["c", "b", "a"]:
        values = np.array(switching_states[phase], dtype=int)

        low = config["trace_levels"][phase]["low"]
        high = config["trace_levels"][phase]["high"]

        y_values = np.where(values == 1, high, low)

        # ax.step requires one extra y-value at the final x-boundary
        x_step = bounds
        y_step = np.r_[y_values, y_values[-1]]

        ax.step(
            x_step,
            y_step,
            where="post",
            color=config["colors"][phase],
            linewidth=config["lw"],
            solid_joinstyle="miter",
            solid_capstyle="butt",
            zorder=3,
        )

    # --------------------------------------------------------
    # PWM labels
    # --------------------------------------------------------
    # Labels are centered horizontally over the full PWM period
    # and vertically in the corresponding PWM row.
    for phase in ["c", "b", "a"]:
        low = config["trace_levels"][phase]["low"]
        high = config["trace_levels"][phase]["high"]

        x_text = 0.5
        y_text = 0.5 * (low + high)

        ax.text(
            x_text,
            y_text,
            config["pwm_labels"][phase],
            color=config["colors"][phase],
            fontsize=config["fs_pwm_label"],
            ha="center",
            va="center",
            zorder=5,
        )

    # --------------------------------------------------------
    # Optional segment duration labels
    # --------------------------------------------------------
    # Disabled by default so that only vector labels are shown.
    if config["show_segment_labels"]:
        for x, label in zip(centers, config["segment_labels"]):
            ax.text(
                x,
                config["duration_label_y"],
                label,
                color=config["colors"]["text"],
                ha="center",
                va="top",
                fontsize=config["fs_duration"],
            )

    # --------------------------------------------------------
    # Voltage-vector labels
    # --------------------------------------------------------
    if config["show_vector_labels"]:
        for x, label in zip(centers, config["vector_labels"]):
            ax.text(
                x,
                config["vector_label_y"],
                label,
                color=config["colors"]["text"],
                ha="center",
                va="center",
                fontsize=config["fs_vector"],
            )

    # --------------------------------------------------------
    # Optional title
    # --------------------------------------------------------
    if config["show_title"]:
        ax.set_title(
            config["title"],
            fontsize=config["fs_title"],
            pad=18,
        )

    # --------------------------------------------------------
    # Optional PWM-period arrow
    # --------------------------------------------------------
    if config["show_period_arrow"]:
        ax.annotate(
            "",
            xy=(1.0, config["period_arrow_y"]),
            xytext=(0.0, config["period_arrow_y"]),
            arrowprops=dict(
                arrowstyle="->",
                linewidth=config["axis_lw"],
                color=config["colors"]["text"],
            ),
        )

        ax.text(
            0.5,
            config["period_label_y"],
            config["period_label"],
            color=config["colors"]["text"],
            ha="center",
            va="top",
            fontsize=config["fs_label"],
        )

    # --------------------------------------------------------
    # Final layout
    # --------------------------------------------------------
    ax.set_xlim(-config["x_margin"], 1.0 + config["x_margin"])
    ax.set_ylim(config["y_limits"])

    # Schematic figure, so remove axes and ticks
    ax.axis("off")

    fig.tight_layout(pad=0.5)

    # --------------------------------------------------------
    # Export
    # --------------------------------------------------------
    fig.savefig(
        config["output_png"],
        dpi=config["dpi"],
        bbox_inches="tight",
        transparent=False,
    )

    if config["save_pdf"]:
        fig.savefig(
            config["output_pdf"],
            bbox_inches="tight",
            transparent=False,
        )

    plt.show()


# ============================================================
# Run script
# ============================================================

if __name__ == "__main__":
    plot_svpwm_switching_pattern(config, switching_states)