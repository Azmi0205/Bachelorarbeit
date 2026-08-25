clc;
clear;
close all;

%% Parameters
U_star = 1;          % PWM amplitude
fm     = 2;          % Reference (modulation) frequency [Hz]
fpwm   = 50;         % PWM switching frequency [Hz]
Tsim   = 1;          % Simulation time [s]
fs     = 1e5;        % Sampling frequency [Hz]

%% Time vector
t = 0:1/fs:Tsim;

%% Reference signal (0...1)
reference = 0.5 * (sin(2*pi*fm*t) + 1);

%% PWM carrier (ramp from 0 to 1)
carrier = sawtooth(2*pi*fpwm*t,1);
carrier = (carrier + 1)/2;

%% PWM generation
pwm_signal = U_star * (reference > carrier);

%% Low-pass filter
fc = 5;
[b,a] = butter(1,fc/(fs/2));
filtered = filter(b,a,pwm_signal);

%% Plot PWM and reference
figure;

subplot(2,1,1)
plot(t, pwm_signal, 'b', 'LineWidth', 1)
hold on
plot(t, reference, 'r', 'LineWidth', 2)
hold off

title('PWM Signal and Reference Signal')
xlabel('Time')
ylabel('Amplitude')
legend('PWM Signal', 'Reference Signal', 'Location', 'northeast')
ylim([-0.1 1.1])
xlim([0 Tsim])
set(gca, 'XTick', [], 'YTick', [])
grid off

%% Plot filtered result
subplot(2,1,2)
plot(t, pwm_signal, 'b', 'LineWidth', 1)
hold on
plot(t, filtered, 'r', 'LineWidth', 2)
plot(t, reference, 'k--', 'LineWidth', 1.5)
hold off

title('Low-Pass Filtered PWM Signal')
xlabel('Time')
ylabel('Amplitude')
legend('PWM Signal', 'Filtered Signal', 'Reference Signal', 'Location', 'northeast')
ylim([-0.1 1.1])
xlim([0 Tsim])
set(gca, 'XTick', [], 'YTick', [])
grid off
