Feature: Burndown
  As a scrum master
  I want to manage sprints and their stories
  So that they get done according the product owner's requirements

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And sharing is enabled
      And the subproject1 project has the backlogs plugin enabled
      And no versions or issues exist
      And I am a scrum master of the project
      And I have selected the ecookbook project
      And I have the following issue statuses available:
        | name        | is_closed | is_default | default_done_ratio |
        | New         |         0 |          1 |                    |
        | Assigned    |         0 |          0 |                    |
        | In Progress |         0 |          0 |                    |
        | Resolved    |         0 |          0 |                    |
        | Feedback    |         0 |          0 |                    |
        | Closed      |         1 |          0 |                    |
        | Accepted    |         1 |          0 |                    |
        | Rejected    |         1 |          0 |                  1 |

      And the current time is 2011-01-01 07:00:00

      And I have defined the following sprints:
        | name           | sprint_start_date | effective_date  | sharing     | project_id |
        | Sprint 001     | 2012-02-02        | 2012-02-09      | descendants | ecookbook  |
        | Sprint siegerv | 2011-08-19        | 2011-09-02      | descendants | ecookbook  |

      And I have defined the following stories in the product backlog:
        | subject | project_id  |
        | Story 1 | ecookbook   |
        | Story 2 | ecookbook   |
        | Story 3 | ecookbook   |
        | Story 4 | subproject1 |
      And I have defined the following stories in the following sprints:
        | subject         | sprint         | points | project_id  |
        | Story A         | Sprint 001     | 1      | ecookbook   |
        | Story B         | Sprint 001     | 2      | ecookbook   |
        | Story C         | Sprint 001     | 4      | subproject1 |
        | Siegerv story 1 | Sprint siegerv | 1      | ecookbook   |

      And I have defined the following tasks:
        | subject      | story            | estimate | status |
        | A.1          | Story A          | 10       | New    |
        | B.1          | Story B          | 20       | New    |
        | C.1          | Story C          | 40       | New    |

        | S.1          | Siegerv story 1  | 10       | New    |

  Scenario: Check baseline without sharing
    Given I have selected the ecookbook project
      And sharing is not enabled
      And I am viewing the master backlog
     Then I should see 3 stories in the product backlog
      And I should see 2 sprint backlogs
     # And I should see 2 stories in the backlog of sprint Sprint 001

  Scenario: Check baseline with sharing
    Given I have selected the ecookbook project
      And I am viewing the master backlog
     Then I should see 4 stories in the product backlog
      And I should see 2 sprint backlogs
     # And I should see 3 stories in the backlog of sprint Sprint 001

  Scenario: Tasks closed AFTER remaining hours is set to 0
    Given I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 1       | A.1  | 5         | In Progress |
        | 1       | B.1  | 10        | In Progress |
        | 2       | A.1  | 0         |             |
        | 2       | A.1  |           | Closed      |
        | 2       | C.1  | 30        | In Progress |
        | 3       | B.1  | 0         |             |
        | 3       | B.1  |           | Closed      |
        | 3       | C.1  | 25        |             |
        | 4       | C.1  | 10        |             |
        | 5       | C.1  | 0         |             |
        | 5       | C.1  |           | Closed      |
      Then the sprint burndown should be:
        | day     | points_committed | points_to_resolve | hours_remaining |
        | start   | 7                | 7                 | 70              |
        | 1       | 7                | 7                 | 55              |
        | 2       | 7                | 6                 | 40              |
        | 3       | 7                | 4                 | 25              |
        | 4       | 7                | 4                 | 10              |
        | 5       | 7                | 0                 | 0               |
       And the sprint burnup should be:
        | day     | points_committed | points_resolved | hours_remaining |
        | start   | 7                | 0               | 70              |
        | 1       | 7                | 0               | 55              |
        | 2       | 7                | 1               | 40              |
        | 3       | 7                | 3               | 25              |
        | 4       | 7                | 3               | 10              |
        | 5       | 7                | 7               | 0               |

  Scenario: Tasks closed BEFORE remaining hours is set to 0
    Given I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 1       | A.1  | 5         | In Progress |
        | 1       | B.1  | 10        | In Progress |
        | 2       | A.1  |           | Closed      |
        | 2       | A.1  | 0         |             |
        | 2       | C.1  | 30        | In Progress |
        | 3       | B.1  |           | Closed      |
        | 3       | B.1  | 0         |             |
        | 3       | C.1  | 25        |             |
        | 4       | C.1  | 10        |             |
        | 5       | C.1  |           | Closed      |
        | 5       | C.1  | 0         |             |

      Then the sprint burndown should be:
        | day     | points_committed | points_to_resolve | hours_remaining |
        | start   | 7                | 7                 | 70              |
        | 1       | 7                | 7                 | 55              |
        | 2       | 7                | 6                 | 40              |
        | 3       | 7                | 4                 | 25              |
        | 4       | 7                | 4                 | 10              |
        | 5       | 7                | 0                 | 0               |

  Scenario: New task and story added during sprint
    Given I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 1       | A.1  | 5         | In Progress |
        | 1       | B.1  | 10        | In Progress |
        | 2       | A.1  | 0         |             |
        | 2       | A.1  |           | Closed      |
        | 2       | C.1  | 30        | In Progress |

      And I have defined the following stories in the following sprints:
        | subject | sprint     | points | day |
        | Story D | Sprint 001 | 4      | 3   |

      And I have defined the following tasks:
        | subject      | story     | estimate | status |
        | D.1          | Story D   | 40       | New    |

      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 3       | B.1  | 0         |             |
        | 3       | B.1  |           | Closed      |
        | 3       | C.1  | 25        |             |
        | 4       | C.1  | 10        |             |
        | 4       | D.1  | 20        | In Progress |
        | 5       | C.1  | 0         |             |
        | 5       | C.1  |           | Closed      |
        | 5       | D.1  | 0         |             |
        | 5       | D.1  |           | Closed      |

      Then the sprint burndown should be:
        | day     | points_committed | points_to_resolve | hours_remaining |
        | start   | 7                | 7                 | 70              |
        | 1       | 7                | 7                 | 55              |
        | 2       | 7                | 6                 | 40              |
        | 3       | 11               | 8                 | 65              |
        | 4       | 11               | 8                 | 30              |
        | 5       | 11               | 0                 | 0               |

  Scenario: Change sprint start date
    Given I am viewing the taskboard for Sprint 001
      And I have changed the sprint start date to 2012-02-03
      And I have defined the following stories in the following sprints:
        | subject | sprint     | points | day                 |
        | Story D | Sprint 001 | 1      | 2012-02-02 01:00:00 |
      And I have changed the sprint start date to 2012-02-02
     Then the sprint burnup should be:
        | day     | points_resolved |
        | start   | 1               |
        | 1       | 1               |

  Scenario: Closed sprint burndown
    Given I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 3       | S.1  | 0         |             |

  Scenario: Saturday and Sunday are included in burndown chart
    Given I have configured backlogs plugin to include Saturday and Sunday in burndown
      And I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 1       | A.1  | 5         | In Progress |
        | 1       | B.1  | 10        | In Progress |
        | 2       | A.1  | 0         |             |
        | 2       | A.1  |           | Closed      |
        | 2       | C.1  | 30        | In Progress |
        | 3       | B.1  | 0         |             |
        | 3       | B.1  |           | Closed      |
        | 3       | C.1  | 25        |             |
        | 4       | C.1  | 10        |             |
        | 5       | C.1  | 5         |             |
        | 6       | C.1  | 1         |             |
        | 7       | C.1  | 0         |             |
        | 7       | C.1  |           | Closed      |
     Then the sprint burndown should be:
        | day     | points_committed | points_to_resolve | hours_remaining |
        | start   | 7                | 7                 | 70              |
        | 1       | 7                | 7                 | 55              |
        | 2       | 7                | 6                 | 40              |
        | 3       | 7                | 4                 | 25              |
        | 4       | 7                | 4                 | 10              |
        | 5       | 7                | 4                 | 5               |
        | 6       | 7                | 4                 | 1               |
        | 7       | 7                | 0                 | 0               |
      And the sprint burnup should be:
        | day     | points_committed | points_resolved | hours_remaining |
        | start   | 7                | 0               | 70              |
        | 1       | 7                | 0               | 55              |
        | 2       | 7                | 1               | 40              |
        | 3       | 7                | 3               | 25              |
        | 4       | 7                | 3               | 10              |
        | 5       | 7                | 3               | 5               |
        | 6       | 7                | 3               | 1               |
        | 7       | 7                | 7               | 0               |
