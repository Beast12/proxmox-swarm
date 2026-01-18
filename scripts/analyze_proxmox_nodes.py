#!/usr/bin/env python3
"""
Analyze Proxmox cluster nodes to determine optimal Docker Swarm manager/worker distribution
"""

import requests
import urllib3
import json
from typing import Dict, List, Tuple

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Configuration
PROXMOX_ENDPOINT = "https://proxmox-1.lan:8006"
API_TOKEN = "root@pam!terraform=d4d5991f-695a-47a7-9a8c-553b5ae3b912"
NODES = ["proxmox-1", "proxmox-2", "proxmox-3", "proxmox-4", "proxmox-5"]

class ProxmoxAnalyzer:
    def __init__(self, endpoint: str, token: str):
        self.endpoint = endpoint.rstrip('/')
        self.headers = {
            'Authorization': f'PVEAPIToken={token}'
        }
        self.session = requests.Session()
        self.session.verify = False
        self.session.headers.update(self.headers)
    
    def get_node_status(self, node: str) -> Dict:
        """Get detailed node status including resources"""
        try:
            response = self.session.get(f'{self.endpoint}/api2/json/nodes/{node}/status')
            response.raise_for_status()
            return response.json()['data']
        except Exception as e:
            print(f"Error getting status for {node}: {e}")
            return {}
    
    def get_node_resources(self, node: str) -> Dict:
        """Get node resource information"""
        try:
            response = self.session.get(f'{self.endpoint}/api2/json/nodes/{node}/resources')
            response.raise_for_status()
            return response.json()['data']
        except Exception as e:
            print(f"Error getting resources for {node}: {e}")
            return {}
    
    def get_cluster_status(self) -> List[Dict]:
        """Get overall cluster status"""
        try:
            response = self.session.get(f'{self.endpoint}/api2/json/cluster/status')
            response.raise_for_status()
            return response.json()['data']
        except Exception as e:
            print(f"Error getting cluster status: {e}")
            return []
    
    def analyze_node(self, node: str) -> Dict:
        """Analyze a single node and return key metrics"""
        status = self.get_node_status(node)
        
        if not status:
            return {'node': node, 'available': False}
        
        # Calculate utilization percentages
        cpu_count = status.get('cpuinfo', {}).get('cpus', 0)
        cpu_usage = status.get('cpu', 0) * 100
        
        memory_total = status.get('memory', {}).get('total', 0)
        memory_used = status.get('memory', {}).get('used', 0)
        memory_usage = (memory_used / memory_total * 100) if memory_total > 0 else 0
        memory_free_gb = (memory_total - memory_used) / (1024**3)
        
        # Storage metrics
        rootfs = status.get('rootfs', {})
        storage_total = rootfs.get('total', 0)
        storage_used = rootfs.get('used', 0)
        storage_usage = (storage_used / storage_total * 100) if storage_total > 0 else 0
        storage_free_gb = (storage_total - storage_used) / (1024**3)
        
        # Get uptime
        uptime_seconds = status.get('uptime', 0)
        uptime_days = uptime_seconds / 86400
        
        # Get load average - ensure float conversion
        loadavg = status.get('loadavg', [0, 0, 0])
        
        return {
            'node': node,
            'available': True,
            'cpu_count': cpu_count,
            'cpu_usage': round(cpu_usage, 2),
            'memory_total_gb': round(memory_total / (1024**3), 2),
            'memory_used_gb': round(memory_used / (1024**3), 2),
            'memory_free_gb': round(memory_free_gb, 2),
            'memory_usage': round(memory_usage, 2),
            'storage_total_gb': round(storage_total / (1024**3), 2),
            'storage_free_gb': round(storage_free_gb, 2),
            'storage_usage': round(storage_usage, 2),
            'uptime_days': round(uptime_days, 2),
            'load_avg_1m': float(loadavg[0]) if len(loadavg) > 0 else 0.0,
            'load_avg_5m': float(loadavg[1]) if len(loadavg) > 1 else 0.0,
            'load_avg_15m': float(loadavg[2]) if len(loadavg) > 2 else 0.0,
        }
    
    def calculate_manager_score(self, node_data: Dict) -> float:
        """
        Calculate a score for manager suitability
        Managers should be on stable, less-loaded nodes with good resources
        """
        if not node_data.get('available'):
            return 0
        
        score = 100
        
        # Penalize high CPU usage (managers need consistent availability)
        cpu_penalty = node_data['cpu_usage'] * 0.5
        score -= cpu_penalty
        
        # Penalize high memory usage
        memory_penalty = (node_data['memory_usage'] - 50) * 0.3 if node_data['memory_usage'] > 50 else 0
        score -= memory_penalty
        
        # Reward high uptime
        uptime_bonus = min(node_data['uptime_days'] * 2, 20)
        score += uptime_bonus
        
        # Penalize high load average relative to CPU count
        if node_data['cpu_count'] > 0:
            load_ratio = node_data['load_avg_5m'] / node_data['cpu_count']
            load_penalty = max(0, (load_ratio - 0.7) * 30)
            score -= load_penalty
        
        # Minimum memory requirement (managers should have at least 2GB free)
        if node_data['memory_free_gb'] < 2:
            score -= 30
        
        return max(0, score)
    
    def calculate_worker_score(self, node_data: Dict) -> float:
        """
        Calculate a score for worker suitability
        Workers should have maximum available resources for workloads
        """
        if not node_data.get('available'):
            return 0
        
        score = 100
        
        # Reward high free memory (workers need resources for containers)
        memory_bonus = node_data['memory_free_gb'] * 5
        score += memory_bonus
        
        # Reward high CPU count
        cpu_bonus = node_data['cpu_count'] * 3
        score += cpu_bonus
        
        # Reward low current utilization (more capacity available)
        utilization_bonus = (100 - node_data['cpu_usage']) * 0.3
        score += utilization_bonus
        
        # Penalize low free storage
        if node_data['storage_free_gb'] < 50:
            score -= 20
        
        return score

def main():
    print("=" * 80)
    print("Proxmox Cluster Analysis for Docker Swarm Deployment")
    print("=" * 80)
    print()
    
    analyzer = ProxmoxAnalyzer(PROXMOX_ENDPOINT, API_TOKEN)
    
    # Analyze all nodes
    node_analyses = []
    for node in NODES:
        print(f"Analyzing {node}...", end=" ")
        analysis = analyzer.analyze_node(node)
        if analysis.get('available'):
            print("✓")
            analysis['manager_score'] = analyzer.calculate_manager_score(analysis)
            analysis['worker_score'] = analyzer.calculate_worker_score(analysis)
            node_analyses.append(analysis)
        else:
            print("✗ (unavailable)")
    
    print()
    print("=" * 80)
    print("Node Details")
    print("=" * 80)
    print()
    
    # Display detailed node information
    for node in sorted(node_analyses, key=lambda x: x['node']):
        print(f"\n📊 {node['node'].upper()}")
        print(f"   CPU:     {node['cpu_count']} cores @ {node['cpu_usage']}% usage (load: {node['load_avg_5m']})")
        print(f"   Memory:  {node['memory_free_gb']:.1f}GB free / {node['memory_total_gb']:.1f}GB total ({node['memory_usage']:.1f}% used)")
        print(f"   Storage: {node['storage_free_gb']:.1f}GB free / {node['storage_total_gb']:.1f}GB total ({node['storage_usage']:.1f}% used)")
        print(f"   Uptime:  {node['uptime_days']:.1f} days")
        print(f"   Scores:  Manager={node['manager_score']:.1f}, Worker={node['worker_score']:.1f}")
    
    print()
    print("=" * 80)
    print("Docker Swarm Recommendations")
    print("=" * 80)
    print()
    
    # Sort for manager candidates
    manager_candidates = sorted(node_analyses, key=lambda x: x['manager_score'], reverse=True)
    worker_candidates = sorted(node_analyses, key=lambda x: x['worker_score'], reverse=True)
    
    if len(node_analyses) == 0:
        print("❌ ERROR: No nodes available for analysis")
        print("   Please check:")
        print("   - Network connectivity to Proxmox cluster")
        print("   - API token validity")
        print("   - Node names are correct")
        return
    
    # Recommend 3 managers (odd number for quorum)
    managers = manager_candidates[:3]
    
    # Remaining nodes as workers
    manager_nodes = {n['node'] for n in managers}
    workers = [n for n in node_analyses if n['node'] not in manager_nodes]
    
    print("🎯 RECOMMENDED CONFIGURATION:")
    print()
    print(f"Manager Nodes ({len(managers)}):")
    for i, node in enumerate(managers, 1):
        role = "Primary Manager" if i == 1 else f"Manager {i}"
        print(f"  {i}. {node['node']:<15} ({role})")
        print(f"     - Score: {node['manager_score']:.1f}")
        print(f"     - CPU: {node['cpu_count']} cores @ {node['cpu_usage']}%")
        print(f"     - Memory: {node['memory_free_gb']:.1f}GB free")
        print(f"     - Uptime: {node['uptime_days']:.1f} days")
        print()
    
    print(f"Worker Nodes ({len(workers)}):")
    for i, node in enumerate(workers, 1):
        print(f"  {i}. {node['node']:<15}")
        print(f"     - Score: {node['worker_score']:.1f}")
        print(f"     - CPU: {node['cpu_count']} cores @ {node['cpu_usage']}%")
        print(f"     - Memory: {node['memory_free_gb']:.1f}GB free")
        print()
    
    print("=" * 80)
    print("Rationale")
    print("=" * 80)
    print()
    print("Manager Selection Criteria:")
    print("  • Stability (uptime) - Managers need consistent availability")
    print("  • Low current load - Ensures responsive cluster management")
    print("  • Adequate memory - Minimum 2GB free for Raft consensus")
    print("  • 3 managers provides quorum (tolerates 1 failure)")
    print()
    print("Worker Selection Criteria:")
    print("  • Maximum available resources (CPU, memory)")
    print("  • Lower current utilization means more capacity for workloads")
    print("  • Workers can be added/removed more flexibly")
    print()
    
    # Export JSON configuration
    if len(managers) > 0:
        config = {
            'managers': [n['node'] for n in managers],
            'workers': [n['node'] for n in workers],
            'primary_manager': managers[0]['node'],
            'analysis_timestamp': None,
            'node_details': node_analyses
        }
        
        with open('swarm_node_config.json', 'w') as f:
            json.dump(config, f, indent=2)
        
        print("💾 Configuration saved to: swarm_node_config.json")
        print()
        print("=" * 80)
        print("Next Steps")
        print("=" * 80)
        print()
        print(f"1. Initialize swarm on primary manager:")
        print(f"   docker swarm init --advertise-addr <{managers[0]['node']}-ip>")
        print()
        print(f"2. Join other managers:")
        print(f"   Get token: docker swarm join-token manager")
        print(f"   Run on: {', '.join([n['node'] for n in managers[1:]])}")
        print()
        print(f"3. Join workers:")
        print(f"   Get token: docker swarm join-token worker")
        print(f"   Run on: {', '.join([n['node'] for n in workers])}")
        print()

if __name__ == '__main__':
    main()