# Optimal-Power-Sharing-in-DC-Grid-Connected-Microgrids-for-Rural-Electrification
Welcome to GC-DC Microgrid Optimal Power Sharing Framework!

GC-DC Microgrid Optimal Power Sharing Framework is a MATLAB-based backend system that models grid-connected DC microgrids with distributed energy resources, including photovoltaic generation and battery energy storage. Using time-series load and generation data, the framework enables simulation of multiple network topologies and operating conditions to analyse power flow and energy distribution across the microgrid.

The framework is designed to optimize power sharing, minimize distribution and converter losses, and coordinate energy exchange between local resources and the utility grid. It evaluates system performance under both local support (peer-to-peer energy sharing) and grid-assisted operation, providing insights into efficient and reliable microgrid operation.

The GC-DC Microgrid Optimal Power Sharing Framework operates as a modular backend architecture, where system initialization, input data processing, optimization, and result generation are handled through structured MATLAB functions. A 24-hour optimal power flow problem is solved using a nonlinear solver (fmincon), incorporating constraints such as power balance, voltage limits, and battery state-of-charge dynamics.

The framework performs time-step simulations to capture the dynamic behaviour of the microgrid. At each time step, nodes are classified based on their net power, and optimal dispatch decisions are computed to balance supply and demand. The result is a detailed representation of power sharing, battery operation, and grid interaction over time, with the potential to be extended into a full software system through frontend integration for user interaction and visualization.

### System Architecture Documentation

The [GC-DC Microgrid/wiki](https://github.com/speedygonzales4/Optimal-Power-Sharing-in-DC-Grid-Connected-Microgrids-for-Rural-Electrification/wiki/GC%E2%80%90DC-Microgrid-Home) is the primary location for documentation of the system architecture, backend implementation, and integration framework. It provides an overview of the model structure, optimization workflow, and the interaction between core computational modules.

* [System Architecture & Implementation](https://github.com/speedygonzales4/Optimal-Power-Sharing-in-DC-Grid-Connected-Microgrids-for-Rural-Electrification/wiki/GC%E2%80%90DC-Microgrid-Tool-Home)
## Scope

This repository is:

* A MATLAB-based backend implementation of a GC-DC microgrid optimal power sharing framework
* A computational model for DC optimal power flow (OPF) with distribution and converter loss considerations
* A modular system for analysing power sharing, battery behaviour, and grid interaction
* A foundation for extending into a full software system with frontend integration

This repository is not:

* A production-ready energy management system
* A fully validated or field-deployed microgrid control solution
* A real-time control or embedded implementation
* A complete software application with a graphical user interface

## Status

Early-stage research and development code. Suitable for academic analysis, experimentation, and further software extension.

## Authors and Contributors

* Aaron Alves - @speedygonzales4
  * Undergraduate student at the University of the West Indies
