# Optimal-Power-Sharing-in-DC-Grid-Connected-Microgrids-for-Rural-Electrification
Welcome to GC-DC Microgrid Optimal Power Sharing Framework!

GC-DC Microgrid Optimal Power Sharing Framework is a MATLAB-based backend system that models grid-connected DC microgrids with distributed energy resources, including photovoltaic generation and battery energy storage. Using time-series load and generation data, the framework enables simulation of multiple network topologies and operating conditions to analyse power flow and energy distribution across the microgrid.

The framework is designed to optimize power sharing, minimize distribution and converter losses, and coordinate energy exchange between local resources and the utility grid. It evaluates system performance under both local support (peer-to-peer energy sharing) and grid-assisted operation, providing insights into efficient and reliable microgrid operation.

The GC-DC Microgrid Optimal Power Sharing Framework operates as a modular backend architecture, where system initialization, input data processing, optimization, and result generation are handled through structured MATLAB functions. A 24-hour optimal power flow problem is solved using a nonlinear solver (fmincon), incorporating constraints such as power balance, voltage limits, and battery state-of-charge dynamics.

The framework performs time-step simulations to capture the dynamic behaviour of the microgrid. At each time step, nodes are classified based on their net power, and optimal dispatch decisions are computed to balance supply and demand. The result is a detailed representation of power sharing, battery operation, and grid interaction over time, with the potential to be extended into a full software system through frontend integration for user interaction and visualization.
