%% SPWM vs SVPWM at Maximum Linear Modulation
clear;
clc;
close all;

%% Electrical angle
theta_deg = linspace(0,360,2000);
theta = deg2rad(theta_deg);

%% DC-link voltage
% The value can be chosen freely. Setting Udc = 1 gives voltages normalized
% with respect to the DC-link voltage.
Udc = 1;

%% Maximum phase voltage amplitudes according to the text
U_star_spwm  = Udc/2;
U_star_svpwm = Udc/sqrt(3);

%% =========================================================================
% SPWM phase voltage references
%% =========================================================================
ua_spwm = U_star_spwm*sin(theta);
ub_spwm = U_star_spwm*sin(theta - 2*pi/3);
uc_spwm = U_star_spwm*sin(theta + 2*pi/3);

%% SPWM duty cycles
da_spwm = 1/2 + ua_spwm/Udc;
db_spwm = 1/2 + ub_spwm/Udc;
dc_spwm = 1/2 + uc_spwm/Udc;

%% Normalized SPWM phase voltage references
va_spwm = ua_spwm/Udc;
vb_spwm = ub_spwm/Udc;
vc_spwm = uc_spwm/Udc;

%% =========================================================================
% SVPWM phase voltage references before common-mode injection
%% =========================================================================
ua_ref = U_star_svpwm*sin(theta);
ub_ref = U_star_svpwm*sin(theta - 2*pi/3);
uc_ref = U_star_svpwm*sin(theta + 2*pi/3);

%% Common-mode voltage according to the text
u_max = max([ua_ref; ub_ref; uc_ref],[],1);
u_min = min([ua_ref; ub_ref; uc_ref],[],1);

u0 = -1/2*(u_max + u_min);

%% Modified SVPWM phase voltage references
ua_svpwm = ua_ref + u0;
ub_svpwm = ub_ref + u0;
uc_svpwm = uc_ref + u0;

%% SVPWM duty cycles
da_svpwm = 1/2 + ua_svpwm/Udc;
db_svpwm = 1/2 + ub_svpwm/Udc;
dc_svpwm = 1/2 + uc_svpwm/Udc;

%% Normalized SVPWM phase voltage references
va_svpwm = ua_svpwm/Udc;
vb_svpwm = ub_svpwm/Udc;
vc_svpwm = uc_svpwm/Udc;

%% =========================================================================
% Line-to-line voltage references
%% =========================================================================
vab_spwm = (ua_spwm - ub_spwm)/Udc;
vbc_spwm = (ub_spwm - uc_spwm)/Udc;
vca_spwm = (uc_spwm - ua_spwm)/Udc;

% The common-mode component cancels in the line-to-line voltages.
% Therefore, using ua_ref, ub_ref, uc_ref or ua_svpwm, ub_svpwm, uc_svpwm
% gives the same result.
vab_svpwm = (ua_svpwm - ub_svpwm)/Udc;
vbc_svpwm = (ub_svpwm - uc_svpwm)/Udc;
vca_svpwm = (uc_svpwm - ua_svpwm)/Udc;

%% SPWM vs SVPWM at Maximum Linear Modulation
clear;
clc;
close all;

%% Electrical angle
theta_deg = linspace(0,360,2000);
theta = deg2rad(theta_deg);

%% DC-link voltage
% Setting Udc = 1 gives all voltages normalized to the DC-link voltage.
Udc = 1;

%% Maximum phase-voltage reference amplitudes from the text
U_star_spwm  = Udc/2;
U_star_svpwm = Udc/sqrt(3);

%% =========================================================================
% SPWM phase-voltage references
%% =========================================================================
ua_spwm = U_star_spwm*sin(theta);
ub_spwm = U_star_spwm*sin(theta - 2*pi/3);
uc_spwm = U_star_spwm*sin(theta + 2*pi/3);

%% SPWM duty cycles
da_spwm = 1/2 + ua_spwm/Udc;
db_spwm = 1/2 + ub_spwm/Udc;
dc_spwm = 1/2 + uc_spwm/Udc;

%% Normalized SPWM phase-voltage references
va_spwm = ua_spwm/Udc;
vb_spwm = ub_spwm/Udc;
vc_spwm = uc_spwm/Udc;

%% =========================================================================
% SVPWM phase-voltage references before common-mode injection
%% =========================================================================
ua_ref = U_star_svpwm*sin(theta);
ub_ref = U_star_svpwm*sin(theta - 2*pi/3);
uc_ref = U_star_svpwm*sin(theta + 2*pi/3);

%% Common-mode voltage from the text
u_max = max([ua_ref; ub_ref; uc_ref],[],1);
u_min = min([ua_ref; ub_ref; uc_ref],[],1);

u0 = -1/2*(u_max + u_min);

%% Modified SVPWM phase-voltage references
ua_svpwm = ua_ref + u0;
ub_svpwm = ub_ref + u0;
uc_svpwm = uc_ref + u0;

%% SVPWM duty cycles
da_svpwm = 1/2 + ua_svpwm/Udc;
db_svpwm = 1/2 + ub_svpwm/Udc;
dc_svpwm = 1/2 + uc_svpwm/Udc;

%% Normalized SVPWM phase-voltage references
va_svpwm = ua_svpwm/Udc;
vb_svpwm = ub_svpwm/Udc;
vc_svpwm = uc_svpwm/Udc;

%% =========================================================================
% Normalized line-to-line voltage references
%% =========================================================================
vab_spwm = (ua_spwm - ub_spwm)/Udc;
vbc_spwm = (ub_spwm - uc_spwm)/Udc;
vca_spwm = (uc_spwm - ua_spwm)/Udc;

vab_svpwm = (ua_svpwm - ub_svpwm)/Udc;
vbc_svpwm = (ub_svpwm - uc_svpwm)/Udc;
vca_svpwm = (uc_svpwm - ua_svpwm)/Udc;

%% =========================================================================
% Plot layout, enlarged version
%% =========================================================================
figure('Color','w','Units','centimeters','Position',[1 1 52 36]);

t = tiledlayout(2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

%% Enlarged plot formatting
scale = 2;

lw = 1.35*scale;

fs_title = 10.5*scale;
fs_axis  = 9.5*scale;
fs_leg   = 8.5*scale;
fs_label = 11*scale;

col_a = [0.85 0.10 0.10];
col_b = [0.10 0.55 0.10];
col_c = [0.10 0.25 0.85];

%% -------------------------------------------------------------------------
% SPWM phase-voltage references
%% -------------------------------------------------------------------------
ax1 = nexttile(1);

plot(theta_deg,va_spwm,'Color',col_a,'LineWidth',lw); hold on
plot(theta_deg,vb_spwm,'Color',col_b,'LineWidth',lw);
plot(theta_deg,vc_spwm,'Color',col_c,'LineWidth',lw);

grid on
xlim([0 360])
ylim([-0.65 0.65])

title('SPWM Phase References, $U^\ast=U_{\mathrm{dc}}/2$', ...
    'Interpreter','latex', ...
    'FontSize',fs_title)

legend('$u_a^\ast$','$u_b^\ast$','$u_c^\ast$', ...
    'Interpreter','latex', ...
    'FontSize',fs_leg, ...
    'Location','northeast', ...
    'Box','on')

set(gca,'FontSize',fs_axis)
xticklabels([])

%% -------------------------------------------------------------------------
% SVPWM phase-voltage references
%% -------------------------------------------------------------------------
ax2 = nexttile(2);

plot(theta_deg,va_svpwm,'Color',col_a,'LineWidth',lw); hold on
plot(theta_deg,vb_svpwm,'Color',col_b,'LineWidth',lw);
plot(theta_deg,vc_svpwm,'Color',col_c,'LineWidth',lw);

grid on
xlim([0 360])
ylim([-0.65 0.65])

title('SVPWM Phase References, $U^\ast=U_{\mathrm{dc}}/\sqrt{3}$', ...
    'Interpreter','latex', ...
    'FontSize',fs_title)

set(gca,'FontSize',fs_axis)
xticklabels([])
yticklabels([])

%% -------------------------------------------------------------------------
% SPWM line-to-line voltage references
%% -------------------------------------------------------------------------
ax3 = nexttile(3);

plot(theta_deg,vab_spwm,'Color',col_a,'LineWidth',lw); hold on
plot(theta_deg,vbc_spwm,'Color',col_b,'LineWidth',lw);
plot(theta_deg,vca_spwm,'Color',col_c,'LineWidth',lw);

grid on
xlim([0 360])
ylim([-1.1 1.1])

title('SPWM Line-to-Line References', ...
    'Interpreter','latex', ...
    'FontSize',fs_title)

legend('$u_{ab}^\ast$','$u_{bc}^\ast$','$u_{ca}^\ast$', ...
    'Interpreter','latex', ...
    'FontSize',fs_leg, ...
    'Location','northeast', ...
    'Box','on')

set(gca,'FontSize',fs_axis)

%% -------------------------------------------------------------------------
% SVPWM line-to-line voltage references
%% -------------------------------------------------------------------------
ax4 = nexttile(4);

plot(theta_deg,vab_svpwm,'Color',col_a,'LineWidth',lw); hold on
plot(theta_deg,vbc_svpwm,'Color',col_b,'LineWidth',lw);
plot(theta_deg,vca_svpwm,'Color',col_c,'LineWidth',lw);

grid on
xlim([0 360])
ylim([-1.1 1.1])

title('SVPWM Line-to-Line References', ...
    'Interpreter','latex', ...
    'FontSize',fs_title)

set(gca,'FontSize',fs_axis)
yticklabels([])

%% Shared labels
xlabel(t,'Electrical Angle $\theta_e$ [deg]', ...
    'Interpreter','latex', ...
    'FontSize',fs_label)

ylabel(t,'Normalized Voltage Reference $u^\ast/U_{\mathrm{dc}}$', ...
    'Interpreter','latex', ...
    'FontSize',fs_label)

%% Common formatting
linkaxes([ax1 ax2 ax3 ax4],'x')

set(findall(gcf,'Type','axes'),'TickLabelInterpreter','latex')
set(findall(gcf,'Type','axes'),'XTick',0:60:360)

%% Optional: improve axis and legend line thickness for enlarged figure
set(findall(gcf,'Type','axes'),'LineWidth',1.0*scale)

legends = findall(gcf,'Type','Legend');
set(legends,'LineWidth',0.75*scale)