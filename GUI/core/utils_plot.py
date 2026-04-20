from typing import List
import matplotlib.pyplot as plt
import matplotlib.path as mpath
from matplotlib.colors import ListedColormap
from mpl_toolkits.mplot3d import Axes3D
from mpl_toolkits.axes_grid1 import make_axes_locatable
from scipy.interpolate import RegularGridInterpolator

import alphashape

from .utils_fileIO import *


def plot_checkerboard(data, nx, ny, nz, save_path = ""):
    cmap = "coolwarm"
    depth1, depth2 = 0, nz - 1
    ax = plt.subplot(221)
    plt.imshow(data[:, :, depth1], cmap = cmap)
    plt.colorbar()
    ax.set_title(f"Depth Slice: {depth1}")
    ax.set_xlabel("Lon")
    ax.set_ylabel("Lat")

    ax = plt.subplot(222)
    plt.imshow(data[:, :, depth2], cmap = cmap)
    plt.colorbar()
    ax.set_title(f"Depth Slice: {depth2}")
    ax.set_xlabel("Lon")
    ax.set_ylabel("Lat")

    center_y = ny // 2
    ax = plt.subplot(223)
    plt.imshow(data[:, center_y, :].T, cmap = cmap)
    plt.colorbar()
    ax.set_title(f"Lon Slice: {center_y}")
    ax.set_xlabel("Lat")
    ax.set_ylabel("Depth")

    center_x = nx // 2
    ax = plt.subplot(224)
    plt.imshow(data[center_x, :, :].T, cmap = cmap)
    plt.colorbar()
    ax.set_title(f"Lat Slice: {center_x}")
    ax.set_xlabel("Lon")
    ax.set_ylabel("Depth")

    if save_path:
        plt.savefig(save_path, bbox_inches = "tight")


def get_colorbar_cax(ax, colorbar_direction):
    if colorbar_direction == 'vertical':
        position = "right"
    else:
        position = "bottom"
    divider = make_axes_locatable(ax)
    cax = divider.append_axes(position, size = "10%", pad = 0.2)
    return cax


def get_cmap(key):
    BlueDarkRed18_Colors = [
        (36 / 255, 0 / 255, 216 / 255),  # 0.0
        (24 / 255, 28 / 255, 247 / 255),  # 1.0
        (40 / 255, 87 / 255, 255 / 255),  # 2.0
        (61 / 255, 135 / 255, 255 / 255),  # 3.0
        (86 / 255, 176 / 255, 255 / 255),  # 4.0
        (117 / 255, 211 / 255, 255 / 255),  # 5.0
        (153 / 255, 234 / 255, 255 / 255),  # 6.0
        (188 / 255, 249 / 255, 255 / 255),  # 7.0
        (234 / 255, 255 / 255, 255 / 255),  # 8.0
        (255 / 255, 255 / 255, 234 / 255),  # 9.0
        (255 / 255, 241 / 255, 188 / 255),  # 10.0
        (255 / 255, 214 / 255, 153 / 255),  # 11.0
        (255 / 255, 172 / 255, 117 / 255),  # 12.0
        (255 / 255, 120 / 255, 86 / 255),  # 13.0
        (255 / 255, 61 / 255, 61 / 255),  # 14.0
        (247 / 255, 39 / 255, 53 / 255),  # 15.0
        (216 / 255, 21 / 255, 47 / 255),  # 16.0
        (165 / 255, 0 / 255, 33 / 255)  # 17.0
    ]

    if key == "BlueDarkRed18":
        BlueDarkRed18 = ListedColormap(BlueDarkRed18_Colors, name = "BlueDarkRed18")
        BlueDarkRed18_r = BlueDarkRed18.reversed()
        cmap = BlueDarkRed18_r
    else:
        cmap = key
    return cmap


def model_idx_to_interp_idx(idx, idx_type = "lon"):
    if idx_type == "lon":
        return idx * (Storage.n_interp_point_lon + 1)
    else:
        return idx * (Storage.n_interp_point_lat + 1)


def is_number(s):
    try:
        return float(s) or True
    except:
        return False


def get_lat_lon(nx, ny, originLat, originLon, dLat, dLon):
    lat_all = np.array([originLat - dLat * (i - 1) for i in range(nx)])
    lon_all = np.array([originLon + dLon * (j - 1) for j in range(ny)])
    return lat_all, lon_all


def get_interp_lat_lon(lat_all, lon_all, n_interp_point_lat = 9, n_interp_point_lon = 9):
    nx, ny = len(lat_all), len(lon_all)
    lat_min, lat_max = min(lat_all), max(lat_all)
    lon_min, lon_max = min(lon_all), max(lon_all)

    n_after_interp_point_lat = (nx - 1) * n_interp_point_lat + nx
    n_after_interp_point_lon = (ny - 1) * n_interp_point_lon + ny

    lat_interp = np.linspace(lat_min, lat_max, n_after_interp_point_lat)[::-1]
    lon_interp = np.linspace(lon_min, lon_max, n_after_interp_point_lon)

    return lat_interp, lon_interp


def get_station_boundary():
    station = Storage.station
    alpha = Storage.convex_hull_alpha
    hull = alphashape.alphashape(station, alpha)
    if hull.geom_type == "Polygon":
        boundary = np.array(hull.exterior.coords)
    # elif hull.geom_type == "MultiPolygon":
    #     bound = [np.array(poly.exterior.coords) for poly in hull.geoms]  # alpha太大, 产生多个独立的区域
    else:
        raise ValueError("convex_hull_alpha is too large")
    return boundary


def get_interp_model_mask(x_interp, y_interp, boundary):
    poly_path = mpath.Path(boundary)

    X, Y = np.meshgrid(x_interp, y_interp)
    points_2d = np.column_stack([X.flatten(), Y.flatten()])
    in_poly = poly_path.contains_points(points_2d)
    mask = in_poly.reshape(X.shape).swapaxes(0, 1)
    return ~mask


def update_plot_cache():
    if Storage.station is None:
        raise FileExistsError("SurfData File not exist")

    if Storage.interp_model_mask is not None:
        return

    Storage.station_boundary = get_station_boundary()

    nx = Storage.ItemWidget["nx"].getContent("int")
    ny = Storage.ItemWidget["ny"].getContent("int")
    originLat = Storage.ItemWidget["originLat"].getContent("float")
    originLon = Storage.ItemWidget["originLon"].getContent("float")
    dLat = Storage.ItemWidget["dLat"].getContent("float")
    dLon = Storage.ItemWidget["dLon"].getContent("float")

    Storage.src_lat, Storage.src_lon = get_lat_lon(nx, ny, originLat, originLon, dLat, dLon)
    Storage.interp_lat, Storage.interp_lon = get_interp_lat_lon(Storage.src_lat, Storage.src_lon)

    Storage.interp_model_mask = get_interp_model_mask(Storage.interp_lat, Storage.interp_lon, Storage.station_boundary)


def update_model_cache(filepath):
    if filepath in Storage.interp_model_cache:
        return

    nx = Storage.ItemWidget["nx"].getContent("int")
    ny = Storage.ItemWidget["ny"].getContent("int")
    nz = Storage.ItemWidget["nz"].getContent("int")
    if filepath.endswith(".bin"):
        vs = loadbinfloat32(filepath).reshape(nx, ny, nz, order = "F")
    else:
        vs = np.load(filepath)

    vs_interp = get_interp_model(vs)
    Storage.interp_model_cache[filepath] = vs_interp


def get_interp_model(data, method = "linear"):
    x = Storage.src_lat
    y = Storage.src_lon
    z = Storage.depth

    x_interp = Storage.interp_lat
    y_interp = Storage.interp_lon
    z_interp = Storage.depth

    interp_func = RegularGridInterpolator((x, y, z), data, method = method)
    x_mesh, y_mesh, z_mesh = np.meshgrid(x_interp, y_interp, z_interp)
    vs_interp = interp_func((x_mesh, y_mesh, z_mesh)).swapaxes(0, 1)

    data_interp = vs_interp
    mask = Storage.interp_model_mask
    data_interp[mask] = np.nan
    return data_interp


def save_image(fig: plt.Figure, filename: str, dpi: int = 300):
    def save_image_thread(fig, filepath, dpi):
        fig.savefig(filepath, dpi = dpi, bbox_inches = "tight")
        fig.canvas.draw()

    if Storage.is_first_info_image_export:
        info_bar("info", "Image Exporting... (Note: SVG export is slower)", "", duration = -1)
        Storage.is_first_info_image_export = False

    image_dir = os.path.join(Storage.localProjectPath, "image")
    os.makedirs(image_dir, exist_ok = True)
    filepath = os.path.join(image_dir, filename)
    fig.savefig(filepath, dpi = dpi, bbox_inches = "tight")
    info_bar("success", "Image Export Success", "")

    # threading.Thread(target = save_image_thread, args = (fig, filepath, dpi)).start()


def plot_inv_grid(fig: plt.Figure, ax: plt.Axes,
                  grid_marker_size = 5,
                  station_marker_size = 20,
                  origin_marker_size = 20,
                  is_plot_image = False,
                  is_plot_grid_point = False,
                  is_plot_station = True,
                  param_key_prefix = ""):
    originLon = Storage.ItemWidget[param_key_prefix + "originLon"].getContent("float")
    originLat = Storage.ItemWidget[param_key_prefix + "originLat"].getContent("float")
    dLon = Storage.ItemWidget[param_key_prefix + "dLon"].getContent("float")
    dLat = Storage.ItemWidget[param_key_prefix + "dLat"].getContent("float")
    nx = Storage.ItemWidget[param_key_prefix + "nx"].getContent("int")
    ny = Storage.ItemWidget[param_key_prefix + "ny"].getContent("int")

    lon_all = [originLon + dLon * (j - 1) for j in range(ny)]
    lat_all = [originLat - dLat * (i - 1) for i in range(nx)]
    Lon_all, Lat_all = np.meshgrid(lon_all, lat_all)
    Lon_inner, Lat_inner = np.meshgrid(lon_all[1:-1], lat_all[1:-1])

    if is_plot_image:
        data = np.zeros_like(Lon_all)
        image_param = {
            "cmap": "seismic",
            "ec": "black",
            "vmin": -1,
            "vmax": 1,
            # "shading": "flat",
            "shading": "nearest"
        }

        ax.pcolormesh(Lon_all, Lat_all, data, **image_param)

    if is_plot_grid_point:
        ax.scatter(Lon_all, Lat_all, s = grid_marker_size, color = "g")
        ax.scatter(Lon_inner, Lat_inner, s = grid_marker_size, color = "r")

    if is_plot_station:
        station = Storage.station
        lat, lon = station[:, 0], station[:, 1]
        ax.scatter(lon, lat, s = station_marker_size, marker = "^", color = "k",
                   picker = True, pickradius = 5)

    w = dLon * (ny - 3)
    h = dLat * (nx - 3)
    rect = plt.Rectangle((originLon, originLat - h), w, h, fill = False, ec = "b", lw = 2, ls = "--")
    ax.add_patch(rect)
    ax.scatter(originLon, originLat, s = origin_marker_size, color = "r")

    lat_min, lat_max = min(lat_all), max(lat_all)
    lon_min, lon_max = min(lon_all), max(lon_all)
    lat_margin = (lat_max - lat_min) * 0.1
    lon_margin = (lon_max - lon_min) * 0.1
    ax.set_xlim(lon_min - lon_margin, lon_max + lon_margin)
    ax.set_ylim(lat_min - lat_margin, lat_max + lat_margin)
    ax.set_xlabel("Longitude(°)", fontsize = 14)
    ax.set_ylabel("Latitude(°)", fontsize = 14)


def plot_init_model_3d(fig: plt.Figure, ax: Axes3D):
    originLon = Storage.ItemWidget["originLon"].getContent("float")
    originLat = Storage.ItemWidget["originLat"].getContent("float")
    dLon = Storage.ItemWidget["dLon"].getContent("float")
    dLat = Storage.ItemWidget["dLat"].getContent("float")
    nx = Storage.ItemWidget["nx"].getContent("int")
    ny = Storage.ItemWidget["ny"].getContent("int")

    lon_all = np.array([originLon + dLon * (j - 1) for j in range(ny)])
    lat_all = np.array([originLat - dLat * (i - 1) for i in range(nx)])

    depth, vel_1d = Storage.depth, Storage.vel_1d
    init_model = np.tile(vel_1d, (nx, ny, 1))

    lat_grid, depth_grid = np.meshgrid(lat_all, depth)

    all_slice = (ny // 4) * np.arange(4)

    cmap = plt.cm.jet
    vmin = np.min(init_model)
    vmax = np.max(init_model)
    norm = plt.Normalize(vmin = vmin, vmax = vmax)

    for idx, slice_idx in enumerate(all_slice):
        model_slice = init_model[:, slice_idx, :].T

        slice_position = lon_all[slice_idx]
        slice_grid = np.full_like(lat_grid, slice_position)

        ax.plot_surface(slice_grid, lat_grid, depth_grid,
                               facecolors = cmap(norm(model_slice)),
                               shade = False,
                               alpha = 1,
                               rstride = 1,
                               cstride = 1,
                               antialiased = True)

    sm = plt.cm.ScalarMappable(cmap = cmap, norm = norm)
    sm.set_array([])
    fig.colorbar(sm, ax = ax, shrink = 0.7, aspect = 20)

    lat_min, lat_max = min(lat_all), max(lat_all)
    lon_min, lon_max = min(lon_all), max(lon_all)
    depth_min, depth_max = min(depth), max(depth)

    lat_margin = (lat_max - lat_min) * 0.1
    lon_margin = (lon_max - lon_min) * 0.1
    depth_margin = (depth_max - depth_min) * 0.1

    ax.set_xlim(lon_min - lon_margin, lon_max + lon_margin)
    ax.set_ylim(lat_min - lat_margin, lat_max + lat_margin)
    ax.set_zlim(depth_min - depth_margin, depth_max + depth_margin)

    ax.invert_zaxis()
    ax.set_xlabel("Longitude(°)", fontsize = 14, labelpad = 2)
    ax.set_ylabel("Latitude(°)", fontsize = 14, labelpad = 2)
    ax.set_zlabel("Depth (km)", fontsize = 14, labelpad = -5)

    ax.view_init(elev = 15, azim = 225, roll = -2.5)


def plot_multi_slice(data, fig: plt.Figure, axs: List[plt.Axes]):
    vmin = Storage.ItemWidget["plot_multi_vmin"].getContent()
    vmax = Storage.ItemWidget["plot_multi_vmax"].getContent()
    cmap = Storage.ItemWidget["plot_multi_cmap"].getContent()
    colorbar_direction = Storage.ItemWidget["plot_multi_colorbar_direction"].getContent()

    layers = Storage.ItemWidget["plot_layer"].getContent()
    if not layers:
        layers = "0"
    layers = list(map(int, layers.strip().split(" ")))

    depz = Storage.depth
    interp_lat = Storage.interp_lat
    interp_lon = Storage.interp_lon
    lat_bound = Storage.station_boundary[:, 0]
    lon_bound = Storage.station_boundary[:, 1]

    vmin = float(vmin) if is_number(vmin) else None
    vmax = float(vmax) if is_number(vmax) else None

    if len(layers) < len(axs):
        layers = layers + [layers[-1]] * (len(axs) - len(layers))

    for ax, layer in zip(axs, layers):
        if layer >= data.shape[-1]:
            layer = -1
        slice_data = data[:, :, layer]
        title_str = f"Depth: {depz[layer]} km"

        if not hasattr(ax, '_my_im'):
            image_param = {
                "cmap": get_cmap(cmap),
                "vmin": vmin,
                "vmax": vmax,
                "shading": "nearest",
            }
            Lon_all, Lat_all = np.meshgrid(interp_lon, interp_lat)
            ax._my_im = ax.pcolormesh(Lon_all, Lat_all, slice_data, **image_param)

            if colorbar_direction == "horizontal":
                ax._my_cbar = fig.colorbar(ax._my_im, ax = ax, location = "bottom")
            else:
                ax._my_cbar = fig.colorbar(ax._my_im, ax = ax, location = "right")

            ax.plot(lon_bound, lat_bound, lw = 0.5, color = "k")

            ax._my_title = ax.set_title(title_str)
            ax.xaxis.set_major_formatter("{x:.1f}°")
            ax.yaxis.set_major_formatter("{x:.1f}°")

        else:
            ax._my_im.set_array(slice_data.ravel())

            ax._my_im.set_cmap(get_cmap(cmap))
            if vmin is not None or vmax is not None:
                ax._my_im.set_clim(vmin, vmax)
            else:
                ax._my_im.autoscale()

            ax._my_title.set_text(title_str)
            ax._my_cbar.update_normal(ax._my_im)


def plot_ortho_slice(data: np.ndarray, plot_type_list: List[str], idx_list: List[int], fig: plt.Figure, axs: List[plt.Axes]):
    vmin = Storage.ItemWidget["plot_ortho_vmin"].getContent()
    vmax = Storage.ItemWidget["plot_ortho_vmax"].getContent()
    cmap = Storage.ItemWidget["plot_ortho_cmap"].getContent()
    colorbar_direction = Storage.ItemWidget["plot_ortho_colorbar_direction"].getContent()

    vmin = float(vmin) if is_number(vmin) else None
    vmax = float(vmax) if is_number(vmax) else None

    depz = Storage.depth
    interp_lat = Storage.interp_lat
    interp_lon = Storage.interp_lon
    lat_bound = Storage.station_boundary[:, 0]
    lon_bound = Storage.station_boundary[:, 1]

    def get_model_slice(plot_type, idx):
        axis_map = {"xy": 2, "xz": 1, "yz": 0}
        if plot_type == "xy":
            return data.take(idx, axis = axis_map[plot_type])
        else:
            return data.take(idx, axis = axis_map[plot_type]).T

    for plot_type, idx, ax in zip(plot_type_list, idx_list, axs):
        model_slice = get_model_slice(plot_type, idx)

        if plot_type == "xy":
            title_str = f"Depth Slice: {depz[idx]} km"
        elif plot_type == "xz":
            title_str = f"Lon Slice: {interp_lon[idx]:.2f}°"
        else:
            title_str = f"Lat Slice: {interp_lat[idx]:.2f}°"

        if not hasattr(ax, '_my_im'):

            if plot_type == "xy":
                Lon_all, Lat_all = np.meshgrid(interp_lon, interp_lat)
                ax._my_im = ax.pcolormesh(Lon_all, Lat_all, model_slice, cmap = get_cmap(cmap), vmin = vmin, vmax = vmax)
            elif plot_type == "xz":
                Lat_all, depz_all = np.meshgrid(interp_lat, depz)
                ax._my_im = ax.pcolormesh(Lat_all, depz_all, model_slice, cmap = get_cmap(cmap), vmin = vmin, vmax = vmax)
                ax.set_ylim(depz_all.min(), depz_all.max())
                ax.invert_yaxis()
            elif plot_type == "yz":
                Lon_all, depz_all = np.meshgrid(interp_lon, depz)
                ax._my_im = ax.pcolormesh(Lon_all, depz_all, model_slice, cmap = get_cmap(cmap), vmin = vmin, vmax = vmax)
                ax.set_ylim(depz_all.min(), depz_all.max())
                ax.invert_yaxis()

            if colorbar_direction == "horizontal":
                cbar_location = "bottom"
                cbar_pad = 0.2
            else:
                cbar_location = "right"
                cbar_pad = 0.05

            if plot_type == "xy":
                ax._my_cbar = fig.colorbar(ax._my_im, ax = ax, location = cbar_location)
            else:
                ax._my_cbar = fig.colorbar(ax._my_im, ax = ax, pad = cbar_pad, location = cbar_location)

            if plot_type == "xy":
                ax.plot(lon_bound, lat_bound, lw = 0.5, color = "k")

            ax._my_title = ax.set_title(title_str, fontsize = 14)
            if plot_type == "xy":
                ax.xaxis.set_major_formatter("{x:.1f}°")
                ax.yaxis.set_major_formatter("{x:.1f}°")
            elif plot_type in ["xz", "yz"]:
                ax.set_ylabel("Depth (km)", fontsize = 12)
                ax.xaxis.set_major_formatter("{x:.1f}°")
        else:
            ax._my_im.set_array(model_slice.ravel())
            ax._my_im.set_cmap(get_cmap(cmap))
            if vmin is not None or vmax is not None:
                ax._my_im.set_clim(vmin, vmax)
            else:
                ax._my_im.autoscale()

            ax._my_title.set_text(title_str)
            ax._my_cbar.update_normal(ax._my_im)